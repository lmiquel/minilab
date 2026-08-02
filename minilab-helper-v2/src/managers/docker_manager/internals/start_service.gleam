import dictionaries/docker_services_dictionary/docker_services_dictionary
import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName,
}
import managers/docker_manager/internals/create_docker_client.{
  type Client, post_empty,
}
import managers/docker_manager/types/docker_error.{type DockerError}

/// Démarre un service (POST /containers/{name}/start).
pub fn start_service(
  client: Client,
  name: ServiceName,
) -> Result(Nil, DockerError) {
  let container_name =
    docker_services_dictionary.get_service(name).container_name
  post_empty(client, "/containers/" <> container_name <> "/start")
}
