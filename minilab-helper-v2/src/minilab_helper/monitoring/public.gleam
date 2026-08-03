import discord_gleam
import discord_gleam/bot
import discord_gleam/discord/snowflake.{type Snowflake}
import discord_gleam/types/message
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import gleam/string
import logging
import minilab_helper/dictionaries/docker_services.{type ServiceName}
import minilab_helper/docker/public as docker
import minilab_helper/monitoring/private
import minilab_helper/monitoring/types.{type ServiceState}

const poll_interval_ms = 60_000

const initial_delay_ms = 5000

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

/// Démarre la boucle de polling des statuts Docker (60s, DM d'alerte sur
/// changement d'état/santé ou crash-loop). Équivalent de
/// monitoring-manager.ts's start()/poll().
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
        private.poll_statuses(state.docker, state.service_states, fn(text) {
          dm(state.bot, state.owner_id, text)
        })

      process.send_after(state.self, poll_interval_ms, Tick)
      actor.continue(PollingState(..state, service_states: new_states))
    }
  }
}

/// Envoie un message privé à l'owner, sans jamais lever d'erreur (comme le
/// try/catch silencieux de dm() en v1).
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
