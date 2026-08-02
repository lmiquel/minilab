import commons/types/health_status.{
  type HealthStatus, Healthy, NoHealthcheck, Starting, Unhealthy,
}

pub fn health_emoji(status: HealthStatus) -> String {
  case status {
    Healthy -> "💚"
    Unhealthy -> "❤️‍🩹"
    Starting -> "⏳"
    NoHealthcheck -> "⬜"
  }
}
