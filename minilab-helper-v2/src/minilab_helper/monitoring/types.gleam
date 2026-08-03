import minilab_helper/commons.{type HealthStatus}

pub type ServiceState {
  ServiceState(
    last_state: String,
    last_health: HealthStatus,
    last_restart_count: Int,
    alerted_restart: Bool,
  )
}
