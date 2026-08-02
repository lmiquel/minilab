import commons/types/resource_usage.{type ResourceUsage, ResourceUsage}
import dictionaries/docker_services_dictionary/docker_services_dictionary
import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName,
}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/result
import gleam/string
import managers/docker_manager/internals/create_docker_client.{
  type Client, get_json,
}
import managers/docker_manager/types/docker_error.{type DockerError, DecodeError}

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
  let container_name =
    docker_services_dictionary.get_service(name).container_name

  use body <- result.try(get_json(
    client,
    "/containers/" <> container_name <> "/stats?stream=false",
  ))

  json.parse(from: body, using: stats_decoder())
  |> result.map_error(fn(err) { DecodeError(string.inspect(err)) })
  |> result.map(compute)
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
fn compute(stats: Stats) -> ResourceUsage {
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
