import commons/types/container_status.{type ContainerStatus}
import commons/types/resource_usage.{type ResourceUsage}
import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName,
}
import managers/docker_manager/internals/create_docker_client
import managers/docker_manager/internals/get_all_statuses
import managers/docker_manager/internals/get_resource_usage
import managers/docker_manager/internals/get_rpi_temperature
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
