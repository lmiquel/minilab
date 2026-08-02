pub type HealthStatus {
  Healthy
  Unhealthy
  Starting
  NoHealthcheck
}

pub fn to_string(status: HealthStatus) -> String {
  case status {
    Healthy -> "healthy"
    Unhealthy -> "unhealthy"
    Starting -> "starting"
    NoHealthcheck -> "none"
  }
}
