import commons/types/container_status.{type ContainerStatus, ContainerStatus}
import commons/types/health_status.{
  type HealthStatus, Healthy, NoHealthcheck, Starting, Unhealthy,
}
import dictionaries/docker_services_dictionary/docker_services_dictionary
import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName,
}
import gleam/dynamic/decode
import gleam/json
import gleam/result
import gleam/string
import managers/docker_manager/internals/create_docker_client.{
  type Client, get_json,
}
import managers/docker_manager/types/docker_error.{type DockerError, DecodeError}

/// Renvoie le statut du conteneur d'un service (GET /containers/{name}/json).
pub fn get_container_status(
  client: Client,
  name: ServiceName,
) -> Result(ContainerStatus, DockerError) {
  let container_name =
    docker_services_dictionary.get_service(name).container_name

  use body <- result.try(get_json(
    client,
    "/containers/" <> container_name <> "/json",
  ))

  json.parse(from: body, using: status_decoder(name))
  |> result.map_error(fn(err) { DecodeError(string.inspect(err)) })
}

fn status_decoder(name: ServiceName) -> decode.Decoder(ContainerStatus) {
  use state <- decode.subfield(["State", "Status"], decode.string)
  use health <- decode.field("State", health_decoder())
  use restart_count <- decode.field("RestartCount", decode.int)

  decode.success(ContainerStatus(
    name: name,
    state: state,
    restart_count: restart_count,
    health: health,
  ))
}

/// `State.Health` est absent quand aucun healthcheck n'est configuré —
/// équivalent de `info.State.Health?.Status ?? "none"` côté v1.
fn health_decoder() -> decode.Decoder(HealthStatus) {
  use health <- decode.optional_field("Health", NoHealthcheck, {
    use status <- decode.field("Status", decode.string)
    decode.success(health_from_string(status))
  })

  decode.success(health)
}

fn health_from_string(status: String) -> HealthStatus {
  case status {
    "healthy" -> Healthy
    "unhealthy" -> Unhealthy
    "starting" -> Starting
    _ -> NoHealthcheck
  }
}
