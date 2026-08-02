import commons/helpers/health_emoji
import commons/types/container_status.{type ContainerStatus}
import commons/types/health_status.{
  type HealthStatus, Healthy, NoHealthcheck, Unhealthy,
}
import dictionaries/docker_services_dictionary/docker_services_dictionary
import gleam/int
import gleam/option.{type Option, None, Some}
import managers/monitoring_manager/types/service_state.{
  type ServiceState, ServiceState,
}

const restart_alert_threshold = 3

/// Diff pur entre l'état précédent et le nouveau statut d'un service :
/// renvoie le nouvel état à mémoriser et les messages à envoyer en DM.
/// Port fidèle de check-status.ts.
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
  let definition = docker_services_dictionary.get_service(status.name)

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

/// Seulement pertinent quand le service est censé tourner : un conteneur
/// arrêté volontairement garde souvent son dernier statut de healthcheck à
/// "unhealthy", ce qui n'a rien d'anormal et ne doit pas alerter.
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
            health_emoji.health_emoji(status.health)
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
                health_emoji.health_emoji(status.health)
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
