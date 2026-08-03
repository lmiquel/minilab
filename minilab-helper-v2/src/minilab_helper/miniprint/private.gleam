import gleam/dynamic/decode
import gleam/erlang/process
import gleam/float
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import minilab_helper/miniprint/types

const miniprint_host = "mini.print"

const moonraker_port = 7125

const mainsail_port = 80

const crowsnest_port = 8080

const fetch_timeout_ms = 4000

const receive_timeout_ms = 4500

// ── Requêtes bas niveau ──────────────────────────────────────────────────

fn fetch_json(url: String) -> Result(String, Nil) {
  use req <- result.try(request.to(url) |> result.replace_error(Nil))

  case
    httpc.configure()
    |> httpc.timeout(fetch_timeout_ms)
    |> httpc.dispatch(req)
  {
    Ok(resp) if resp.status >= 200 && resp.status < 300 -> Ok(resp.body)
    Ok(_) -> Error(Nil)
    Error(_) -> Error(Nil)
  }
}

fn check_reachable(url: String) -> Bool {
  case request.to(url) {
    Error(Nil) -> False
    Ok(req) ->
      case
        httpc.configure()
        |> httpc.timeout(fetch_timeout_ms)
        |> httpc.dispatch(req)
      {
        Ok(_) -> True
        Error(_) -> False
      }
  }
}

fn receive_result(
  subject: process.Subject(Result(String, Nil)),
) -> Result(String, Nil) {
  process.receive(subject, within: receive_timeout_ms)
  |> result.unwrap(Error(Nil))
}

fn receive_bool(subject: process.Subject(Bool)) -> Bool {
  process.receive(subject, within: receive_timeout_ms) |> result.unwrap(False)
}

fn decode_body(
  body: Result(String, Nil),
  decoder: decode.Decoder(a),
) -> Option(a) {
  case body {
    Error(Nil) -> None
    Ok(text) ->
      case json.parse(from: text, using: decoder) {
        Ok(value) -> Some(value)
        Error(_) -> None
      }
  }
}

// ── Décodeurs Moonraker ──────────────────────────────────────────────────

fn server_info_decoder() -> decode.Decoder(String) {
  use state <- decode.subfield(["result", "klippy_state"], decode.string)
  decode.success(state)
}

fn klippy_state_from_string(state: String) -> Option(types.KlippyState) {
  case state {
    "ready" -> Some(types.Ready)
    "startup" -> Some(types.Startup)
    "shutdown" -> Some(types.Shutdown)
    "error" -> Some(types.Error)
    _ -> None
  }
}

type ProcStats {
  ProcStats(
    latest_memory_kb: Option(Int),
    throttled_bits: Int,
    cpu_temp: Float,
    cpu_percent: Float,
    uptime_sec: Int,
  )
}

fn proc_stats_decoder() -> decode.Decoder(ProcStats) {
  use memory_samples <- decode.subfield(
    ["result", "moonraker_stats"],
    decode.list({
      use memory <- decode.field("memory", decode.int)
      decode.success(memory)
    }),
  )
  use throttled_bits <- decode.subfield(
    ["result", "throttled_state", "bits"],
    decode.int,
  )
  use cpu_temp <- decode.subfield(["result", "cpu_temp"], decode.float)
  use cpu_percent <- decode.subfield(
    ["result", "system_cpu_usage", "cpu"],
    decode.float,
  )
  use uptime_sec <- decode.subfield(["result", "system_uptime"], decode.int)

  decode.success(ProcStats(
    latest_memory_kb: list.last(memory_samples) |> option.from_result,
    throttled_bits: throttled_bits,
    cpu_temp: cpu_temp,
    cpu_percent: cpu_percent,
    uptime_sec: uptime_sec,
  ))
}

fn total_memory_decoder() -> decode.Decoder(Int) {
  use total_memory <- decode.subfield(
    ["result", "system_info", "cpu_info", "total_memory"],
    decode.int,
  )
  decode.success(total_memory)
}

type DiskUsage {
  DiskUsage(total: Int, used: Int)
}

fn directory_decoder() -> decode.Decoder(DiskUsage) {
  use total <- decode.subfield(["result", "disk_usage", "total"], decode.int)
  use used <- decode.subfield(["result", "disk_usage", "used"], decode.int)
  decode.success(DiskUsage(total: total, used: used))
}

fn bytes_to_gb(bytes: Int) -> Float {
  float.to_precision(int.to_float(bytes) /. 1024.0 /. 1024.0 /. 1024.0, 1)
}

fn kb_to_mb(kb: Int) -> Int {
  float.round(int.to_float(kb) /. 1024.0)
}

// ── Overview ─────────────────────────────────────────────────────────────

pub fn get_overview() -> types.MiniPrintOverview {
  let moonraker =
    "http://" <> miniprint_host <> ":" <> int.to_string(moonraker_port)

  let server_info_subj = process.new_subject()
  process.spawn_unlinked(fn() {
    process.send(server_info_subj, fetch_json(moonraker <> "/server/info"))
  })

  let proc_stats_subj = process.new_subject()
  process.spawn_unlinked(fn() {
    process.send(
      proc_stats_subj,
      fetch_json(moonraker <> "/machine/proc_stats"),
    )
  })

  let system_info_subj = process.new_subject()
  process.spawn_unlinked(fn() {
    process.send(
      system_info_subj,
      fetch_json(moonraker <> "/machine/system_info"),
    )
  })

  let directory_subj = process.new_subject()
  process.spawn_unlinked(fn() {
    process.send(
      directory_subj,
      fetch_json(moonraker <> "/server/files/directory?path=gcodes"),
    )
  })

  let mainsail_subj = process.new_subject()
  process.spawn_unlinked(fn() {
    process.send(
      mainsail_subj,
      check_reachable(
        "http://"
        <> miniprint_host
        <> ":"
        <> int.to_string(mainsail_port)
        <> "/",
      ),
    )
  })

  let crowsnest_subj = process.new_subject()
  process.spawn_unlinked(fn() {
    process.send(
      crowsnest_subj,
      check_reachable(
        "http://"
        <> miniprint_host
        <> ":"
        <> int.to_string(crowsnest_port)
        <> "/",
      ),
    )
  })

  let klippy_state_str =
    decode_body(receive_result(server_info_subj), server_info_decoder())
  let proc_stats =
    decode_body(receive_result(proc_stats_subj), proc_stats_decoder())
  let total_memory_kb =
    decode_body(receive_result(system_info_subj), total_memory_decoder())
  let disk_usage =
    decode_body(receive_result(directory_subj), directory_decoder())
  let mainsail_up = receive_bool(mainsail_subj)
  let crowsnest_up = receive_bool(crowsnest_subj)

  let moonraker_up = option.is_some(klippy_state_str)

  types.MiniPrintOverview(
    reachable: moonraker_up || mainsail_up,
    cpu_temp_c: option.map(proc_stats, fn(p) { p.cpu_temp }),
    cpu_percent: option.map(proc_stats, fn(p) { p.cpu_percent }),
    moonraker_mem_mb: option.then(proc_stats, fn(p) {
      option.map(p.latest_memory_kb, kb_to_mb)
    }),
    total_mem_mb: option.map(total_memory_kb, kb_to_mb),
    uptime_sec: option.map(proc_stats, fn(p) { p.uptime_sec }),
    throttled: option.map(proc_stats, fn(p) {
      types.ThrottledState(bits: p.throttled_bits)
    }),
    storage: option.map(disk_usage, fn(d) {
      types.PrinterStorageInfo(
        used_gb: bytes_to_gb(d.used),
        total_gb: bytes_to_gb(d.total),
        percent: float.to_precision(
          int.to_float(d.used) /. int.to_float(d.total) *. 100.0,
          1,
        ),
      )
    }),
    mainsail_up: mainsail_up,
    moonraker_up: moonraker_up,
    klippy_state: option.then(klippy_state_str, klippy_state_from_string),
    crowsnest_up: crowsnest_up,
  )
}
