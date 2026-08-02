import commons/types/container_status.{type ContainerStatus}
import dictionaries/docker_services_dictionary/derived/monitored_services
import gleam/list
import managers/docker_manager/internals/create_docker_client.{type Client}
import managers/docker_manager/internals/get_container_status
import managers/docker_manager/types/docker_error.{type DockerError}

/// Renvoie le statut de tous les services surveillés. Comme le `Promise.all`
/// du v1, échoue entièrement dès qu'un seul service ne répond pas.
pub fn get_all_statuses(
  client: Client,
) -> Result(List(ContainerStatus), DockerError) {
  monitored_services.monitored_services()
  |> list.try_map(fn(name) {
    get_container_status.get_container_status(client, name)
  })
}
