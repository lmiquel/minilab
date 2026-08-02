import envoy
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/option.{None, Some}
import gleam/string
import gleam/uri
import managers/docker_manager/types/docker_error.{
  type DockerError, HttpError, UnexpectedStatus,
}

pub type Client {
  Client(host: String, port: Int)
}

pub fn create_docker_client() -> Client {
  let assert Ok(docker_host) = envoy.get("DOCKER_HOST")
  let assert Ok(parsed) = uri.parse(docker_host)
  let assert Some(host) = parsed.host

  let port = case parsed.port {
    Some(port) -> port
    None -> 2375
  }

  Client(host: host, port: port)
}

/// Effectue un GET sur le docker-socket-proxy et renvoie le corps brut.
pub fn get_json(client: Client, path: String) -> Result(String, DockerError) {
  let req =
    request.new()
    |> request.set_scheme(http.Http)
    |> request.set_host(client.host)
    |> request.set_port(client.port)
    |> request.set_method(http.Get)
    |> request.set_path(path)

  case httpc.send(req) {
    Ok(resp) if resp.status == 200 -> Ok(resp.body)
    Ok(resp) -> Error(UnexpectedStatus(resp.status, resp.body))
    Error(err) -> Error(HttpError(string.inspect(err)))
  }
}
