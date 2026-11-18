import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import minilab_helper/dictionaries/docker_services.{type ServiceName}
import minilab_helper/dictionaries/service_categories
import minilab_helper/docker.{type ContainerStatus, type DockerError}

const discord_content_limit = 2000

const truncated_notice = "\n-# … message tronqué"

pub type StatusResults =
  List(#(ServiceName, Result(ContainerStatus, DockerError)))

type ServiceLine {
  Detailed(String)
  Stopped(label: String)
}

pub fn build_status_message(client: docker.Client) -> String {
  render_services_message(
    ["## 📊 Statut du minilab"],
    docker.get_status_results(client),
    fn(_) { None },
  )
}

pub fn build_resources_message(client: docker.Client) -> String {
  let statuses = docker.get_status_results(client)
  let usages =
    docker.get_all_resource_usages(client, running_services(statuses))

  render_services_message(
    [
      "## 📈 Ressources — minilab",
      temperature_text(docker.get_rpi_temperature()),
    ],
    statuses,
    fn(service) { resource_details(usages, service, True) },
  )
}

pub fn build_overview_message(client: docker.Client) -> String {
  let statuses = docker.get_status_results(client)
  let usages =
    docker.get_all_resource_usages(client, running_services(statuses))

  render_services_message(
    [
      "## 📊 Overview",
      temperature_text(docker.get_rpi_temperature())
        <> " · "
        <> host_text(docker.get_host_resources()),
      storage_text(docker.get_storage_usage()),
    ],
    statuses,
    fn(service) { resource_details(usages, service, False) },
  )
}

pub fn render_services_message(
  header: List(String),
  statuses: StatusResults,
  details: fn(ServiceName) -> Option(String),
) -> String {
  let sections =
    statuses
    |> list.map(fn(pair) { pair.0 })
    |> docker_services.group_by_category
    |> list.map(fn(pair) { render_category(pair.0, pair.1, statuses, details) })

  [string.join(header, "\n"), ..sections]
  |> string.join("\n")
  |> fit_discord_content
}

fn render_category(
  category: service_categories.ServiceCategory,
  services: List(ServiceName),
  statuses: StatusResults,
  details: fn(ServiceName) -> Option(String),
) -> String {
  let lines =
    list.map(services, fn(service) {
      service_line(service, list.key_find(statuses, service), details)
    })

  let detailed =
    list.filter_map(lines, fn(line) {
      case line {
        Detailed(text) -> Ok(text)
        Stopped(_) -> Error(Nil)
      }
    })

  let stopped_line = case
    list.filter_map(lines, fn(line) {
      case line {
        Stopped(label) -> Ok(label)
        Detailed(_) -> Error(Nil)
      }
    })
  {
    [] -> []
    labels -> ["-# ⚫ Arrêtés : " <> string.join(labels, ", ")]
  }

  ["### " <> service_categories.category_label(category)]
  |> list.append(detailed)
  |> list.append(stopped_line)
  |> string.join("\n")
}

fn service_line(
  service: ServiceName,
  status: Result(Result(ContainerStatus, DockerError), Nil),
  details: fn(ServiceName) -> Option(String),
) -> ServiceLine {
  let definition = docker_services.get_service(service)
  let name = definition.emoji <> " **" <> definition.label <> "**"

  case status {
    Ok(Ok(container))
      if container.state == "exited" || container.state == "created"
    -> Stopped(definition.label)

    Ok(Ok(container)) if container.state == "running" -> {
      let #(dot, note) = case container.health {
        docker.Healthy -> #("💚", "")
        docker.NoHealthcheck -> #("🟢", "")
        docker.Starting -> #("⏳", "`starting`")
        docker.Unhealthy -> #("❤️‍🩹", "`unhealthy`")
      }
      Detailed(
        compose_line(dot, name, [
          note,
          option.unwrap(details(service), ""),
          restarts_text(container.restart_count),
        ]),
      )
    }

    Ok(Ok(container)) ->
      Detailed(
        compose_line("🔴", name, [
          "`" <> container.state <> "`",
          restarts_text(container.restart_count),
        ]),
      )

    _ -> Detailed(compose_line("❔", name, ["`indisponible`"]))
  }
}

fn compose_line(dot: String, name: String, parts: List(String)) -> String {
  case list.filter(parts, fn(part) { part != "" }) {
    [] -> dot <> " " <> name
    kept -> dot <> " " <> name <> " — " <> string.join(kept, " · ")
  }
}

fn restarts_text(restart_count: Int) -> String {
  case restart_count {
    0 -> ""
    count -> "🔁 " <> int.to_string(count)
  }
}

fn running_services(statuses: StatusResults) -> List(ServiceName) {
  list.filter_map(statuses, fn(pair) {
    case pair.1 {
      Ok(container) if container.state == "running" -> Ok(pair.0)
      _ -> Error(Nil)
    }
  })
}

fn resource_details(
  usages: dict.Dict(ServiceName, Result(docker.ResourceUsage, DockerError)),
  service: ServiceName,
  with_mem_percent: Bool,
) -> Option(String) {
  case dict.get(usages, service) {
    Ok(Ok(usage)) -> {
      let mem_percent = case with_mem_percent {
        True -> " (" <> float.to_string(usage.mem_percent) <> "%)"
        False -> ""
      }
      Some(
        "CPU `"
        <> float.to_string(usage.cpu_percent)
        <> "%` · RAM `"
        <> format_mem(usage.mem_usage_mb)
        <> "`"
        <> mem_percent,
      )
    }
    Ok(Error(_)) -> Some("❌ stats indisponibles")
    Error(Nil) -> None
  }
}

pub fn temperature_text(temperature: Result(Int, a)) -> String {
  case temperature {
    Ok(celsius) -> {
      let warning = case celsius >= 70, celsius >= 60 {
        True, _ -> " 🔴"
        False, True -> " 🟡"
        False, False -> ""
      }
      "🌡️ " <> int.to_string(celsius) <> "°C" <> warning
    }
    Error(_) -> "🌡️ ❌"
  }
}

fn host_text(host: Result(docker.HostResources, a)) -> String {
  case host {
    Ok(host) ->
      "🖥️ CPU `"
      <> float.to_string(host.cpu_percent)
      <> "%` · RAM `"
      <> format_gb(host.mem_used_mb)
      <> "/"
      <> format_gb(host.mem_total_mb)
      <> " Go`"
    Error(_) -> "🖥️ ❌"
  }
}

fn storage_text(storage: Result(docker.HostStorageUsage, a)) -> String {
  case storage {
    Ok(storage) ->
      "💾 SD `"
      <> int.to_string(float.round(storage.sd.used_gb))
      <> "/"
      <> int.to_string(float.round(storage.sd.total_gb))
      <> " Go` · SSD `"
      <> int.to_string(float.round(storage.ssd.used_gb))
      <> "/"
      <> int.to_string(float.round(storage.ssd.total_gb))
      <> " Go`"
    Error(_) -> "💾 ❌"
  }
}

pub fn format_mem(megabytes: Int) -> String {
  case megabytes >= 1024 {
    True -> format_gb(megabytes) <> " Go"
    False -> int.to_string(megabytes) <> " Mo"
  }
}

fn format_gb(megabytes: Int) -> String {
  float.to_string(float.to_precision(int.to_float(megabytes) /. 1024.0, 1))
}

pub fn fit_discord_content(content: String) -> String {
  case discord_length(content) <= discord_content_limit {
    True -> content
    False ->
      string.split(content, "\n")
      |> take_lines(
        [],
        0,
        discord_content_limit - discord_length(truncated_notice),
      )
      |> string.join("\n")
      |> string.append(truncated_notice)
  }
}

fn take_lines(
  lines: List(String),
  kept: List(String),
  used: Int,
  budget: Int,
) -> List(String) {
  case lines {
    [] -> list.reverse(kept)
    [line, ..rest] -> {
      let cost = discord_length(line) + 1
      case used + cost > budget {
        True -> list.reverse(kept)
        False -> take_lines(rest, [line, ..kept], used + cost, budget)
      }
    }
  }
}

pub fn discord_length(text: String) -> Int {
  string.to_utf_codepoints(text)
  |> list.fold(0, fn(total, codepoint) {
    case string.utf_codepoint_to_int(codepoint) > 0xFFFF {
      True -> total + 2
      False -> total + 1
    }
  })
}
