import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import minilab_helper/commands/views.{
  discord_length, fit_discord_content, format_mem, render_services_message,
  temperature_text,
}
import minilab_helper/dictionaries/docker_services.{
  Cobblemon, Nextcloud, PingvinShare, ProjectZomboid, Valheim, Vaultwarden,
  monitored_services,
}
import minilab_helper/docker.{
  ContainerStatus, Healthy, HttpError, NoHealthcheck, ResourceUsage, Starting,
}

fn running(service, health) {
  #(
    service,
    Ok(ContainerStatus(
      name: service,
      state: "running",
      restart_count: 0,
      health: health,
    )),
  )
}

fn with_state(service, state, restart_count) {
  #(
    service,
    Ok(ContainerStatus(
      name: service,
      state: state,
      restart_count: restart_count,
      health: NoHealthcheck,
    )),
  )
}

fn no_details(_service) {
  None
}

pub fn running_services_get_a_line_and_stopped_ones_are_grouped_test() {
  let message =
    render_services_message(
      ["## Titre"],
      [
        running(Valheim, Healthy),
        with_state(Cobblemon, "exited", 0),
        with_state(ProjectZomboid, "created", 0),
      ],
      no_details,
    )

  assert message
    == "## Titre\n### 🎮 Jeux\n💚 🌲 **Valheim**\n-# ⚫ Arrêtés : Cobblemon, Project Zomboid"
}

pub fn categories_follow_the_fixed_order_test() {
  let message =
    render_services_message(
      ["## Titre"],
      [running(Nextcloud, Healthy), running(Valheim, NoHealthcheck)],
      no_details,
    )

  assert message
    == "## Titre\n### 🎮 Jeux\n🟢 🌲 **Valheim**\n### 💻 Web Apps\n💚 📁 **Nextcloud**"
}

pub fn anomalies_and_restarts_are_spelled_out_test() {
  let message =
    render_services_message(
      ["## Titre"],
      [
        running(Nextcloud, Starting),
        with_state(PingvinShare, "running", 2),
        with_state(Vaultwarden, "restarting", 5),
      ],
      no_details,
    )

  assert message
    == "## Titre\n### 💻 Web Apps\n⏳ 📁 **Nextcloud** — `starting`\n🟢 🐧 **Pingvin Share** — 🔁 2\n🔴 🔐 **Vaultwarden** — `restarting` · 🔁 5"
}

pub fn unreachable_container_only_affects_its_own_line_test() {
  let message =
    render_services_message(
      ["## Titre"],
      [running(Valheim, Healthy), #(Cobblemon, Error(HttpError("404")))],
      no_details,
    )

  assert message
    == "## Titre\n### 🎮 Jeux\n💚 🌲 **Valheim**\n❔ 🎊 **Cobblemon** — `indisponible`"
}

pub fn details_are_only_asked_for_running_services_test() {
  let message =
    render_services_message(
      ["## Titre"],
      [running(Valheim, Healthy), with_state(Cobblemon, "exited", 0)],
      fn(_) { Some("CPU `4.1%`") },
    )

  assert message
    == "## Titre\n### 🎮 Jeux\n💚 🌲 **Valheim** — CPU `4.1%`\n-# ⚫ Arrêtés : Cobblemon"
}

pub fn format_mem_switches_to_gigabytes_test() {
  assert format_mem(512) == "512 Mo"
  assert format_mem(1229) == "1.2 Go"
}

pub fn temperature_text_flags_hot_values_test() {
  assert temperature_text(Ok(52)) == "🌡️ 52°C"
  assert temperature_text(Ok(64)) == "🌡️ 64°C 🟡"
  assert temperature_text(Ok(75)) == "🌡️ 75°C 🔴"
  assert temperature_text(Error(Nil)) == "🌡️ ❌"
}

pub fn discord_length_counts_emojis_as_two_units_test() {
  assert discord_length("abc") == 3
  assert discord_length("🌲") == 2
}

pub fn short_content_is_left_untouched_test() {
  assert fit_discord_content("## Titre\nligne") == "## Titre\nligne"
}

pub fn long_content_is_cut_on_a_line_boundary_test() {
  let line = "💚 🌲 **Valheim** — CPU `4.1%` · RAM `1.2 Go`"
  let content = list.repeat(line, 100) |> string.join("\n")
  let fitted = fit_discord_content(content)

  assert discord_length(fitted) <= 2000
  assert string.ends_with(fitted, "\n-# … message tronqué")
  assert list.all(string.split(fitted, "\n"), fn(l) {
    l == line || l == "-# … message tronqué"
  })
}

pub fn full_overview_fits_in_one_message_test() {
  let statuses = list.map(monitored_services(), fn(s) { running(s, Healthy) })
  let usages =
    dict.from_list(
      list.map(monitored_services(), fn(s) {
        #(
          s,
          ResourceUsage(
            cpu_percent: 12.5,
            mem_usage_mb: 1229,
            mem_percent: 15.3,
          ),
        )
      }),
    )
  let message =
    render_services_message(
      [
        "## 📊 Overview",
        "🌡️ 52°C · 🖥️ CPU `23.4%` · RAM `3.1/7.6 Go`",
        "💾 SD `31/58 Go` · SSD `7/117 Go`",
      ],
      statuses,
      fn(service) {
        case dict.get(usages, service) {
          Ok(usage) ->
            Some("CPU `12.5%` · RAM `" <> format_mem(usage.mem_usage_mb) <> "`")
          Error(Nil) -> None
        }
      },
    )

  assert !string.ends_with(message, "message tronqué")
  assert discord_length(message) <= 2000
}
