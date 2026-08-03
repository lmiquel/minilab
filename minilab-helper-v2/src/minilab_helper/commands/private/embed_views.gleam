import discord_gleam/types/embed
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import minilab_helper/commands/private
import minilab_helper/common.{type ContainerStatus, format_date_fr}
import minilab_helper/dictionaries/docker_services.{monitored_services}
import minilab_helper/docker/public as docker
import minilab_helper/docker/types.{type DockerError} as _
import minilab_helper/wireguard/types.{type ConnectedPeer} as _

const color_blurple = 0x5865F2

const color_green = 0x57F287

const color_grey = 0x95A5A6

// ── /status ──────────────────────────────────────────────────────────────

/// Port de build-status-embed.ts. Comme le v1, échoue entièrement si
/// get_all_statuses échoue (`Promise.all` fail-fast côté v1).
pub fn build_status_embed(
  client: docker.Client,
) -> Result(embed.Embed, DockerError) {
  use statuses <- result.try(docker.get_all_statuses(client))

  let base =
    embed.new(
      title: "📊 Statut du minilab",
      description: "",
      color: color_blurple,
    )

  let with_fields =
    private.add_grouped_service_fields(base, monitored_services(), fn(service) {
      status_field_value(statuses, service)
    })

  Ok(with_fields)
}

fn status_field_value(statuses: List(ContainerStatus), service) {
  case list.find(statuses, fn(status) { status.name == service }) {
    Error(Nil) -> None
    Ok(status) ->
      Some(
        private.render_container_state_line(status)
        <> "  •  🔁 "
        <> int.to_string(status.restart_count),
      )
  }
}

// ── /resources ───────────────────────────────────────────────────────────

/// Port de build-resources-embed.ts. À la différence de /status, une panne
/// sur un service n'est jamais fatale : elle affiche juste
/// "❌ Stats indisponibles" pour ce service.
pub fn build_resources_embed(client: docker.Client) -> embed.Embed {
  let description = case docker.get_rpi_temperature() {
    Ok(temp) ->
      "🌡️ Température RPi : "
      <> private.temp_emoji(temp)
      <> " **"
      <> int.to_string(temp)
      <> "°C**"
    Error(_) -> "🌡️ Température RPi : ❌ indisponible"
  }

  let base =
    embed.new(
      title: "📈 Ressources CPU / RAM — minilab",
      description: description,
      color: color_green,
    )

  private.add_grouped_service_fields(base, monitored_services(), fn(service) {
    let value = case docker.get_resource_usage(client, service) {
      Ok(usage) ->
        "CPU : `"
        <> float.to_string(usage.cpu_percent)
        <> "%`\nRAM : `"
        <> int.to_string(usage.mem_usage_mb)
        <> "MB ("
        <> float.to_string(usage.mem_percent)
        <> "%)`"
      Error(_) -> "❌ Stats indisponibles\n(conteneur arrêté ?)"
    }
    Some(value)
  })
}

// ── /vpn ─────────────────────────────────────────────────────────────────

/// Port de build-vpn-embed.ts.
pub fn build_vpn_embed(peers: List(ConnectedPeer)) -> embed.Embed {
  case peers {
    [] ->
      embed.new(
        title: "🔒 Peers VPN connectés",
        description: "Aucun peer connecté actuellement.",
        color: color_grey,
      )

    _ -> {
      let base =
        embed.new(
          title: "🔒 Peers VPN connectés",
          description: "",
          color: color_green,
        )

      list.fold(peers, base, fn(embed, peer) {
        embed.add_field(
          embed,
          name: "🟢 " <> peer.name,
          value: "Dernier handshake : `" <> format_date_fr(peer.since) <> "`",
          inline: False,
        )
      })
    }
  }
}
