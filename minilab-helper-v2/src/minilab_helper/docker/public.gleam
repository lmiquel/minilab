import minilab_helper/common.{type ContainerStatus, type ResourceUsage}
import minilab_helper/dictionaries/docker_services.{type ServiceName}
import minilab_helper/docker/private
import minilab_helper/docker/types.{type DockerError}

pub type Client =
  private.Client

pub fn new_client() -> Client {
  private.create_docker_client()
}

pub fn get_all_statuses(
  client: Client,
) -> Result(List(ContainerStatus), DockerError) {
  private.get_all_statuses(client)
}

pub fn get_resource_usage(
  client: Client,
  service: ServiceName,
) -> Result(ResourceUsage, DockerError) {
  private.get_resource_usage(client, service)
}

pub fn get_rpi_temperature() -> Result(Int, Nil) {
  private.get_rpi_temperature()
}

pub fn start_service(
  client: Client,
  service: ServiceName,
) -> Result(Nil, DockerError) {
  private.start_service(client, service)
}

pub fn stop_service(
  client: Client,
  service: ServiceName,
) -> Result(Nil, DockerError) {
  private.stop_service(client, service)
}

pub fn restart_service(
  client: Client,
  service: ServiceName,
) -> Result(Nil, DockerError) {
  private.restart_service(client, service)
}

pub fn exec(
  client: Client,
  service: ServiceName,
  cmd: String,
) -> Result(String, DockerError) {
  private.exec_in_container(client, service, cmd)
}
