import envoy
import gleam/bit_array
import gleam/dynamic/decode
import gleam/erlang/charlist
import gleam/erlang/process
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
import minilab_helper/dictionaries/docker_services.{type ServiceName}
import simplifile

pub type DockerError {
  HttpError(String)
  UnexpectedStatus(Int, String)
  DecodeError(String)
}

pub type HealthStatus {
  Healthy
  Unhealthy
  Starting
  NoHealthcheck
}

pub fn health_status_to_string(status: HealthStatus) -> String {
  case status {
    Healthy -> "healthy"
    Unhealthy -> "unhealthy"
    Starting -> "starting"
    NoHealthcheck -> "none"
  }
}

pub fn health_emoji(status: HealthStatus) -> String {
  case status {
    Healthy -> "💚"
    Unhealthy -> "❤️‍🩹"
    Starting -> "⏳"
    NoHealthcheck -> "⬜"
  }
}

pub type ContainerStatus {
  ContainerStatus(
    name: ServiceName,
    state: String,
    restart_count: Int,
    health: HealthStatus,
  )
}

pub type ResourceUsage {
  ResourceUsage(cpu_percent: Float, mem_usage_mb: Int, mem_percent: Float)
}

pub type HostResources {
  HostResources(
    cpu_percent: Float,
    mem_used_mb: Int,
    mem_total_mb: Int,
    mem_percent: Float,
  )
}

pub type HostStorageInfo {
  HostStorageInfo(used_gb: Float, total_gb: Float, percent: Float)
}

pub type HostStorageUsage {
  HostStorageUsage(sd: HostStorageInfo, ssd: HostStorageInfo)
}

// ── Client & requêtes bas niveau ─────────────────────────────────────────

pub type Client {
  Client(host: String, port: Int)
}

pub fn new_client() -> Client {
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
fn get_json(client: Client, path: String) -> Result(String, DockerError) {
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
fn post_empty(client: Client, path: String) -> Result(Nil, DockerError) {
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
fn post_json(
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
fn post_json_bits(
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
fn get_container_status(
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

// ── Ressources hôte ──────────────────────────────────────────────────────

const host_stat_path = "/host/stat"

const host_meminfo_path = "/host/meminfo"

const sd_mount_path = "/host/rootfs"

const ssd_mount_path = "/host/ssd"

pub fn get_host_resources() -> Result(HostResources, Nil) {
  use stat1 <- result.try(read_cpu_stat())
  process.sleep(500)
  use stat2 <- result.try(read_cpu_stat())
  let cpu_percent = calc_cpu_percent(stat1, stat2)

  use #(total_kb, avail_kb) <- result.try(read_meminfo())
  let mem_total_mb = float.round(int.to_float(total_kb) /. 1024.0)
  let mem_avail_mb = float.round(int.to_float(avail_kb) /. 1024.0)
  let mem_used_mb = mem_total_mb - mem_avail_mb
  let mem_percent =
    float.to_precision(
      int.to_float(mem_used_mb) /. int.to_float(mem_total_mb) *. 100.0,
      1,
    )

  Ok(HostResources(
    cpu_percent: cpu_percent,
    mem_used_mb: mem_used_mb,
    mem_total_mb: mem_total_mb,
    mem_percent: mem_percent,
  ))
}

fn read_cpu_stat() -> Result(List(Int), Nil) {
  use raw <- result.try(
    simplifile.read(from: host_stat_path) |> result.replace_error(Nil),
  )
  use line <- result.try(
    string.split(raw, "\n")
    |> list.find(fn(l) { string.starts_with(l, "cpu ") }),
  )

  line
  |> string.drop_start(4)
  |> string.trim
  |> string.split(" ")
  |> list.filter(fn(s) { s != "" })
  |> list.try_map(int.parse)
}

fn calc_cpu_percent(a: List(Int), b: List(Int)) -> Float {
  let total_a = list.fold(a, 0, fn(acc, x) { acc + x })
  let total_b = list.fold(b, 0, fn(acc, x) { acc + x })
  let idle_a = list.drop(a, 3) |> list.first |> result.unwrap(0)
  let idle_b = list.drop(b, 3) |> list.first |> result.unwrap(0)

  let total_delta = total_b - total_a
  let idle_delta = idle_b - idle_a

  case total_delta == 0 {
    True -> 0.0
    False ->
      float.to_precision(
        int.to_float(total_delta - idle_delta)
          /. int.to_float(total_delta)
          *. 100.0,
        1,
      )
  }
}

fn read_meminfo() -> Result(#(Int, Int), Nil) {
  use raw <- result.try(
    simplifile.read(from: host_meminfo_path) |> result.replace_error(Nil),
  )
  use total_kb <- result.try(meminfo_field(raw, "MemTotal"))
  use avail_kb <- result.try(meminfo_field(raw, "MemAvailable"))
  Ok(#(total_kb, avail_kb))
}

fn meminfo_field(raw: String, key: String) -> Result(Int, Nil) {
  string.split(raw, "\n")
  |> list.find_map(fn(line) {
    case string.split_once(line, ":") {
      Ok(#(k, v)) if k == key ->
        v |> string.trim |> string.replace(" kB", "") |> int.parse
      _ -> Error(Nil)
    }
  })
}

pub fn get_storage_usage() -> Result(HostStorageUsage, Nil) {
  use sd <- result.try(df_info(sd_mount_path))
  use ssd <- result.try(df_info(ssd_mount_path))
  Ok(HostStorageUsage(sd: sd, ssd: ssd))
}

fn df_info(path: String) {
  let output =
    os_cmd(charlist.from_string("df -Pk " <> path)) |> charlist.to_string

  use data_line <- result.try(
    string.split(output, "\n") |> list.drop(1) |> list.first,
  )

  use #(total_str, avail_str) <- result.try(
    case string.split(data_line, " ") |> list.filter(fn(s) { s != "" }) {
      [_, total, _, avail, ..] -> Ok(#(total, avail))
      _ -> Error(Nil)
    },
  )

  use total_kb <- result.try(int.parse(total_str))
  use avail_kb <- result.try(int.parse(avail_str))

  let total_gb = kb_to_gb(total_kb)
  let avail_gb = kb_to_gb(avail_kb)
  let used_gb = float.to_precision(total_gb -. avail_gb, 1)
  let percent = float.to_precision(used_gb /. total_gb *. 100.0, 1)

  Ok(HostStorageInfo(used_gb: used_gb, total_gb: total_gb, percent: percent))
}

fn kb_to_gb(kb: Int) -> Float {
  float.to_precision(int.to_float(kb) /. 1024.0 /. 1024.0, 1)
}

@external(erlang, "os", "cmd")
fn os_cmd(command: charlist.Charlist) -> charlist.Charlist

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

pub fn exec(
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
