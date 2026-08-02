import commons/types/health_status.{type HealthStatus}
import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName,
}

pub type ContainerStatus {
  ContainerStatus(
    name: ServiceName,
    state: String,
    restart_count: Int,
    health: HealthStatus,
  )
}
