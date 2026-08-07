import discord_gleam
import discord_gleam/bot
import discord_gleam/discord/snowflake.{type Snowflake}
import discord_gleam/types/message
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/string
import logging
import minilab_helper/dictionaries/docker_services.{type ServiceName}
import minilab_helper/docker.{
  type ContainerStatus, type HealthStatus, Healthy, NoHealthcheck, Unhealthy,
}

const poll_interval_ms = 60_000

const initial_delay_ms = 5000

const restart_alert_threshold = 3

pub type ServiceState {
  ServiceState(
    last_state: String,
    last_health: HealthStatus,
    last_restart_count: Int,
    alerted_restart: Bool,
  )
}

pub type Tick {
  Tick
}

type PollingState {
  PollingState(
    self: Subject(Tick),
    bot: bot.Bot,
    owner_id: Snowflake(snowflake.User),
    docker: docker.Client,
    service_states: dict.Dict(ServiceName, ServiceState),
  )
}

pub fn start(
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
  docker: docker.Client,
) -> Result(actor.Started(Subject(Tick)), actor.StartError) {
  actor.new_with_initialiser(1000, fn(subject) {
    process.send_after(subject, initial_delay_ms, Tick)

    actor.initialised(PollingState(
      self: subject,
      bot: bot,
      owner_id: owner_id,
      docker: docker,
      service_states: dict.new(),
    ))
    |> actor.returning(subject)
    |> Ok
  })
  |> actor.on_message(handle_message)
  |> actor.start()
}

fn handle_message(
  state: PollingState,
  msg: Tick,
) -> actor.Next(PollingState, Tick) {
  case msg {
    Tick -> {
      let new_states =
        poll_statuses(state.docker, state.service_states, fn(text) {
          dm(state.bot, state.owner_id, text)
        })

      process.send_after(state.self, poll_interval_ms, Tick)
      actor.continue(PollingState(..state, service_states: new_states))
    }
  }
}

pub fn dm(
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
  text: String,
) -> Nil {
  case discord_gleam.send_direct_message(bot, owner_id, message.new(text)) {
    Ok(_) -> Nil
    Error(err) ->
      logging.log(
        logging.Error,
        "[Monitor] Erreur envoi DM: " <> string.inspect(err),
      )
  }
}

// ── Diff pur (port fidèle de check-status.ts) ───────────────────────────

pub fn check_status(
  status: ContainerStatus,
  previous: Result(ServiceState, Nil),
) -> #(ServiceState, List(String)) {
  case previous {
    Error(Nil) -> #(baseline(status), [])
    Ok(prev) -> diff(status, prev)
  }
}

fn baseline(status: ContainerStatus) -> ServiceState {
  ServiceState(
    last_state: status.state,
    last_health: status.health,
    last_restart_count: status.restart_count,
    alerted_restart: False,
  )
}

fn diff(
  status: ContainerStatus,
  prev: ServiceState,
) -> #(ServiceState, List(String)) {
  let definition = docker_services.get_service(status.name)

  let #(state_alert, new_last_state, alerted_restart_after_state) =
    diff_state(status, prev, definition.label, definition.emoji)

  let #(health_alert, new_last_health) =
    diff_health(status, prev, definition.label, definition.container_name)

  let #(restart_alert, new_alerted_restart) =
    diff_restart_count(
      status,
      prev,
      alerted_restart_after_state,
      definition.label,
      definition.container_name,
    )

  let new_state =
    ServiceState(
      last_state: new_last_state,
      last_health: new_last_health,
      last_restart_count: status.restart_count,
      alerted_restart: new_alerted_restart,
    )

  #(new_state, option.values([state_alert, health_alert, restart_alert]))
}

fn diff_state(
  status: ContainerStatus,
  prev: ServiceState,
  label: String,
  emoji: String,
) -> #(Option(String), String, Bool) {
  case prev.last_state == status.state {
    True -> #(None, prev.last_state, prev.alerted_restart)

    False ->
      case status.state {
        "running" -> #(
          Some(
            "✅ **"
            <> label
            <> "** est de nouveau `running` (était `"
            <> prev.last_state
            <> "`)",
          ),
          status.state,
          False,
        )

        _ -> #(
          Some(
            emoji
            <> " **"
            <> label
            <> "** vient de passer à l'état `"
            <> status.state
            <> "`\n"
            <> "État précédent : `"
            <> prev.last_state
            <> "`\n"
            <> "Redémarrages Docker : "
            <> int.to_string(status.restart_count),
          ),
          status.state,
          False,
        )
      }
  }
}

fn diff_health(
  status: ContainerStatus,
  prev: ServiceState,
  label: String,
  container_name: String,
) -> #(Option(String), HealthStatus) {
  let health_changed =
    prev.last_health != status.health && status.health != NoHealthcheck

  let new_last_health = case health_changed {
    True -> status.health
    False -> prev.last_health
  }

  let alert = case health_changed && status.state == "running" {
    False -> None
    True ->
      case status.health {
        Unhealthy ->
          Some(
            docker.health_emoji(status.health)
            <> " **"
            <> label
            <> "** est `unhealthy` !\n"
            <> "Vérifie les logs : `docker logs --tail 50 "
            <> container_name
            <> "`",
          )

        Healthy ->
          case prev.last_health == Unhealthy {
            True ->
              Some(
                docker.health_emoji(status.health)
                <> " **"
                <> label
                <> "** est de nouveau `healthy`.",
              )
            False -> None
          }

        _ -> None
      }
  }

  #(alert, new_last_health)
}

fn diff_restart_count(
  status: ContainerStatus,
  prev: ServiceState,
  alerted_restart: Bool,
  label: String,
  container_name: String,
) -> #(Option(String), Bool) {
  let is_crash_loop =
    status.restart_count > prev.last_restart_count
    && status.restart_count >= restart_alert_threshold
    && !alerted_restart

  case is_crash_loop {
    False -> #(None, alerted_restart)
    True -> #(
      Some(
        "🔁 **"
        <> label
        <> "** a redémarré **"
        <> int.to_string(status.restart_count)
        <> " fois** depuis son lancement.\n"
        <> "Il est peut-être dans une boucle de crash. Vérifie les logs :\n"
        <> "`docker logs --tail 50 "
        <> container_name
        <> "`",
      ),
      True,
    )
  }
}

// ── Cycle de polling (impur, port de poll-statuses.ts) ──────────────────

fn poll_statuses(
  client: docker.Client,
  states: Dict(ServiceName, ServiceState),
  dm: fn(String) -> Nil,
) -> Dict(ServiceName, ServiceState) {
  case docker.get_all_statuses(client) {
    Error(err) -> {
      dm(
        "⚠️ **Une erreur docker est survenue !**\n**"
        <> string.inspect(err)
        <> "**",
      )
      states
    }

    Ok(statuses) ->
      list.fold(statuses, states, fn(acc, status) {
        let previous = dict.get(acc, status.name)
        let #(new_state, alerts) = check_status(status, previous)
        list.each(alerts, dm)
        dict.insert(acc, status.name, new_state)
      })
  }
}
