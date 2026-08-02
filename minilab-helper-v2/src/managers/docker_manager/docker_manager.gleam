import commons/types/container_status.{type ContainerStatus}
import commons/types/resource_usage.{type ResourceUsage}
import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName,
}
import managers/docker_manager/internals/create_docker_client
import managers/docker_manager/internals/get_all_statuses
import managers/docker_manager/internals/get_resource_usage
import managers/docker_manager/internals/get_rpi_temperature
import managers/docker_manager/internals/restart_service
import managers/docker_manager/internals/start_service
import managers/docker_manager/internals/stop_service
import managers/docker_manager/types/docker_error.{type DockerError}

pub type Client =
  create_docker_client.Client

pub fn new_client() -> Client {
  create_docker_client.create_docker_client()
}

pub fn get_all_statuses(
  client: Client,
) -> Result(List(ContainerStatus), DockerError) {
  get_all_statuses.get_all_statuses(client)
}

pub fn get_resource_usage(
  client: Client,
  service: ServiceName,
) -> Result(ResourceUsage, DockerError) {
  get_resource_usage.get_resource_usage(client, service)
}

pub fn get_rpi_temperature() -> Result(Int, Nil) {
  get_rpi_temperature.get_rpi_temperature()
}

pub fn start_service(
  client: Client,
  service: ServiceName,
) -> Result(Nil, DockerError) {
  start_service.start_service(client, service)
}

pub fn stop_service(
  client: Client,
  service: ServiceName,
) -> Result(Nil, DockerError) {
  stop_service.stop_service(client, service)
}

pub fn restart_service(
  client: Client,
  service: ServiceName,
) -> Result(Nil, DockerError) {
  restart_service.restart_service(client, service)
}
