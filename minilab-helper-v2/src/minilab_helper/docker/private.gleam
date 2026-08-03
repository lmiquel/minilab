import envoy
import gleam/bit_array
import gleam/dynamic/decode
import gleam/float
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/uri
import minilab_helper/common.{
  type ContainerStatus, type HealthStatus, type ResourceUsage, ContainerStatus,
  Healthy, NoHealthcheck, ResourceUsage, Starting, Unhealthy,
}
import minilab_helper/dictionaries/docker_services.{type ServiceName}
import minilab_helper/docker/types.{
  type DockerError, DecodeError, HttpError, UnexpectedStatus,
}
import simplifile

// ── Client & requêtes bas niveau ─────────────────────────────────────────

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

/// POST à corps vide. 204 et 304 (déjà démarré/arrêté) sont des succès.
pub fn post_empty(client: Client, path: String) -> Result(Nil, DockerError) {
  let req =
    request.new()
    |> request.set_scheme(http.Http)
    |> request.set_host(client.host)
    |> request.set_port(client.port)
    |> request.set_method(http.Post)
    |> request.set_path(path)
    |> request.set_body("")

  case httpc.send(req) {
    Ok(resp) if resp.status == 204 || resp.status == 304 -> Ok(Nil)
    Ok(resp) -> Error(UnexpectedStatus(resp.status, resp.body))
    Error(err) -> Error(HttpError(string.inspect(err)))
  }
}

/// POST avec un corps JSON, renvoie le corps de la réponse (200/201 = succès).
pub fn post_json(
  client: Client,
  path: String,
  body: String,
) -> Result(String, DockerError) {
  let req =
    request.new()
    |> request.set_scheme(http.Http)
    |> request.set_host(client.host)
    |> request.set_port(client.port)
    |> request.set_method(http.Post)
    |> request.set_path(path)
    |> request.set_header("content-type", "application/json")
    |> request.set_body(body)

  case httpc.send(req) {
    Ok(resp) if resp.status == 200 || resp.status == 201 -> Ok(resp.body)
    Ok(resp) -> Error(UnexpectedStatus(resp.status, resp.body))
    Error(err) -> Error(HttpError(string.inspect(err)))
  }
}

/// POST avec un corps JSON, renvoie le corps brut de la réponse (BitArray,
/// pas de décodage UTF-8) — utilisé pour lire un flux Docker exec multiplexé
/// sans corrompre les en-têtes de frame binaires.
pub fn post_json_bits(
  client: Client,
  path: String,
  body: String,
) -> Result(BitArray, DockerError) {
  let req =
    request.new()
    |> request.set_scheme(http.Http)
    |> request.set_host(client.host)
    |> request.set_port(client.port)
    |> request.set_method(http.Post)
    |> request.set_path(path)
    |> request.set_header("content-type", "application/json")
    |> request.set_body(bit_array.from_string(body))

  case httpc.send_bits(req) {
    Ok(resp) if resp.status == 200 -> Ok(resp.body)
    Ok(resp) ->
      Error(UnexpectedStatus(
        resp.status,
        bit_array.to_string(resp.body) |> result.unwrap(""),
      ))
    Error(err) -> Error(HttpError(string.inspect(err)))
  }
}

// ── Statuts ──────────────────────────────────────────────────────────────

/// Renvoie le statut du conteneur d'un service (GET /containers/{name}/json).
pub fn get_container_status(
  client: Client,
  name: ServiceName,
) -> Result(ContainerStatus, DockerError) {
  let container_name = docker_services.get_service(name).container_name

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

/// Renvoie le statut de tous les services surveillés. Comme le `Promise.all`
/// du v1, échoue entièrement dès qu'un seul service ne répond pas.
pub fn get_all_statuses(
  client: Client,
) -> Result(List(ContainerStatus), DockerError) {
  docker_services.monitored_services()
  |> list.try_map(fn(name) { get_container_status(client, name) })
}

// ── Ressources ───────────────────────────────────────────────────────────

type CpuStats {
  CpuStats(total_usage: Int, system_cpu_usage: Int, online_cpus: Int)
}

type MemoryStats {
  MemoryStats(usage: Int, inactive_file: Int, limit: Int)
}

type Stats {
  Stats(cpu: CpuStats, precpu: CpuStats, memory: MemoryStats)
}

/// Récupère un snapshot des stats CPU/RAM (GET /containers/{name}/stats?stream=false).
pub fn get_resource_usage(
  client: Client,
  name: ServiceName,
) -> Result(ResourceUsage, DockerError) {
  let container_name = docker_services.get_service(name).container_name

  use body <- result.try(get_json(
    client,
    "/containers/" <> container_name <> "/stats?stream=false",
  ))

  json.parse(from: body, using: stats_decoder())
  |> result.map_error(fn(err) { DecodeError(string.inspect(err)) })
  |> result.map(compute_resource_usage)
}

fn cpu_stats_decoder() -> decode.Decoder(CpuStats) {
  use total_usage <- decode.optional_field("cpu_usage", 0, {
    use v <- decode.optional_field("total_usage", 0, decode.int)
    decode.success(v)
  })
  use system_cpu_usage <- decode.optional_field(
    "system_cpu_usage",
    0,
    decode.int,
  )
  use online_cpus <- decode.optional_field("online_cpus", 0, decode.int)

  decode.success(CpuStats(total_usage, system_cpu_usage, online_cpus))
}

fn memory_stats_decoder() -> decode.Decoder(MemoryStats) {
  use usage <- decode.optional_field("usage", 0, decode.int)
  use inactive_file <- decode.optional_field("stats", 0, {
    use v <- decode.optional_field("inactive_file", 0, decode.int)
    decode.success(v)
  })
  use limit <- decode.optional_field("limit", 0, decode.int)

  decode.success(MemoryStats(usage, inactive_file, limit))
}

fn stats_decoder() -> decode.Decoder(Stats) {
  use cpu <- decode.field("cpu_stats", cpu_stats_decoder())
  use precpu <- decode.field("precpu_stats", cpu_stats_decoder())
  use memory <- decode.field("memory_stats", memory_stats_decoder())

  decode.success(Stats(cpu, precpu, memory))
}

/// Port fidèle du calcul de get-resource-usage.ts, avec deux corrections :
/// une garde explicite quand le delta système est nul (le v1 laisse le JS
/// produire un NaN/Infinity silencieux), et `online_cpus` dérivé plutôt que
/// figé à 4 (hypothèse "toujours un Pi 4 cœurs" du v1).
fn compute_resource_usage(stats: Stats) -> ResourceUsage {
  let cpu_delta = int.to_float(stats.cpu.total_usage - stats.precpu.total_usage)
  let system_delta =
    int.to_float(stats.cpu.system_cpu_usage - stats.precpu.system_cpu_usage)
  let online_cpus = case stats.cpu.online_cpus {
    0 -> 1
    n -> n
  }

  let cpu_percent = case system_delta >. 0.0 {
    True -> cpu_delta /. system_delta *. int.to_float(online_cpus) *. 100.0
    False -> 0.0
  }

  let mem_used = stats.memory.usage - stats.memory.inactive_file
  let mem_limit = case stats.memory.limit {
    0 -> 1
    n -> n
  }

  ResourceUsage(
    cpu_percent: float.to_precision(cpu_percent, 1),
    mem_usage_mb: mem_used / 1024 / 1024,
    mem_percent: float.to_precision(
      int.to_float(mem_used) /. int.to_float(mem_limit) *. 100.0,
      1,
    ),
  )
}

const thermal_zone_path = "/sys/class/thermal/thermal_zone0/temp"

/// Lit la température du RPi en °C (le fichier contient des millidegrés).
pub fn get_rpi_temperature() -> Result(Int, Nil) {
  use raw <- result.try(
    simplifile.read(from: thermal_zone_path) |> result.replace_error(Nil),
  )
  use millidegrees <- result.try(
    string.trim(raw) |> int.parse |> result.replace_error(Nil),
  )

  Ok(float.round(int.to_float(millidegrees) /. 1000.0))
}

// ── Contrôle ─────────────────────────────────────────────────────────────

/// Démarre un service (POST /containers/{name}/start).
pub fn start_service(
  client: Client,
  name: ServiceName,
) -> Result(Nil, DockerError) {
  let container_name = docker_services.get_service(name).container_name
  post_empty(client, "/containers/" <> container_name <> "/start")
}

/// Arrête proprement un service (POST /containers/{name}/stop?t=10).
pub fn stop_service(
  client: Client,
  name: ServiceName,
) -> Result(Nil, DockerError) {
  let container_name = docker_services.get_service(name).container_name
  post_empty(client, "/containers/" <> container_name <> "/stop?t=10")
}

/// Redémarre un service (POST /containers/{name}/restart?t=10).
pub fn restart_service(
  client: Client,
  name: ServiceName,
) -> Result(Nil, DockerError) {
  let container_name = docker_services.get_service(name).container_name
  post_empty(client, "/containers/" <> container_name <> "/restart?t=10")
}

// ── Exec ─────────────────────────────────────────────────────────────────

/// Exécute une commande dans le conteneur d'un service et renvoie son
/// stdout. Le flux Docker exec est multiplexé (en-tête de 8 octets par
/// frame) quand `Tty` est désactivé — on ne garde que les frames stdout
/// (type 1), le stderr est ignoré comme en v1.
pub fn exec_in_container(
  client: Client,
  name: ServiceName,
  cmd: String,
) -> Result(String, DockerError) {
  let container_name = docker_services.get_service(name).container_name
  let args = string.split(cmd, " ")

  use exec_id <- result.try(create_exec(client, container_name, args))
  use raw <- result.try(start_exec(client, exec_id))

  demux_stdout(raw, <<>>)
  |> bit_array.to_string
  |> result.map_error(fn(_) { DecodeError("Sortie exec non-UTF8") })
}

fn create_exec(
  client: Client,
  container_name: String,
  args: List(String),
) -> Result(String, DockerError) {
  let body =
    json.object([
      #("AttachStdout", json.bool(True)),
      #("AttachStderr", json.bool(True)),
      #("Cmd", json.array(args, of: json.string)),
    ])
    |> json.to_string

  use response <- result.try(post_json(
    client,
    "/containers/" <> container_name <> "/exec",
    body,
  ))

  json.parse(from: response, using: {
    use id <- decode.field("Id", decode.string)
    decode.success(id)
  })
  |> result.map_error(fn(err) { DecodeError(string.inspect(err)) })
}

fn start_exec(
  client: Client,
  exec_id: String,
) -> Result(BitArray, DockerError) {
  let body =
    json.object([#("Detach", json.bool(False)), #("Tty", json.bool(False))])
    |> json.to_string

  post_json_bits(client, "/exec/" <> exec_id <> "/start", body)
}

fn demux_stdout(bits: BitArray, acc: BitArray) -> BitArray {
  case bits {
    <<stream_type, 0, 0, 0, size:size(32), rest:bits>> ->
      case rest {
        <<payload:bytes-size(size), remaining:bits>> -> {
          let new_acc = case stream_type {
            1 -> bit_array.append(acc, payload)
            _ -> acc
          }
          demux_stdout(remaining, new_acc)
        }
        _ -> acc
      }
    _ -> acc
  }
}
