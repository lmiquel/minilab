import commons/helpers/health_emoji
import commons/types/container_status.{type ContainerStatus}
import commons/types/health_status

/// Si healthcheck dispo → on affiche uniquement son résultat (running
/// implicite). Sinon → on affiche l'état Docker.
pub fn render_container_state_line(status: ContainerStatus) -> String {
  let is_running = status.state == "running"
  let has_health = status.health != health_status.NoHealthcheck

  case has_health && is_running {
    True ->
      health_emoji.health_emoji(status.health)
      <> " `"
      <> health_status.to_string(status.health)
      <> "`"

    False -> {
      let dot = case is_running {
        True -> "🟢"
        False -> "🔴"
      }
      dot <> " `" <> status.state <> "`"
    }
  }
}
