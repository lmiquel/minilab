import discord_gleam/types/embed
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import minilab_helper/commands/private
import minilab_helper/common.{
  type ContainerStatus, type PeerInfo, format_date_fr,
}
import minilab_helper/dictionaries/docker_services.{monitored_services}
import minilab_helper/docker/public as docker
import minilab_helper/docker/types.{type DockerError} as _
import minilab_helper/miniprint/types.{type MiniPrintOverview, Ready} as miniprint_types
import minilab_helper/wireguard/types.{type ConnectedPeer} as _

const color_blurple = 0x5865F2

const color_green = 0x57F287

const color_orange = 0xE67E22

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

// ── /miniprint ───────────────────────────────────────────────────────────

const miniprint_title = "🖨️ MiniPrint — Statut & Ressources"

/// Port de build-miniprint-embed.ts.
pub fn build_miniprint_embed(
  overview: MiniPrintOverview,
  peer: Option(PeerInfo),
) -> embed.Embed {
  case overview.reachable {
    False ->
      embed.new(
        title: miniprint_title,
        description: "❌ MiniPrint est injoignable (VPN down, ou Pi éteint).",
        color: color_grey,
      )
      |> embed.add_field(
        name: "🔒 VPN",
        value: miniprint_peer_line(peer),
        inline: False,
      )

    True -> {
      let temp_str = case overview.cpu_temp_c {
        Some(temp) ->
          private.temp_emoji_float(temp)
          <> " **"
          <> float.to_string(temp)
          <> "°C**"
        None -> "❌ indisponible"
      }

      let cpu_str = case overview.cpu_percent {
        Some(percent) -> "`" <> float.to_string(percent) <> "%`"
        None -> "❌"
      }

      let mem_str = case overview.moonraker_mem_mb {
        None -> "❌ indisponible"
        Some(moonraker_mb) -> {
          let total_part = case overview.total_mem_mb {
            Some(total_mb) ->
              " • RAM totale `" <> int.to_string(total_mb) <> "MB`"
            None -> ""
          }
          "Moonraker `" <> int.to_string(moonraker_mb) <> "MB`" <> total_part
        }
      }

      let storage_str = case overview.storage {
        Some(storage) ->
          "💾 `"
          <> float.to_string(storage.used_gb)
          <> "/"
          <> float.to_string(storage.total_gb)
          <> " GB ("
          <> float.to_string(storage.percent)
          <> "%)`"
        None -> "💾 ❌ indisponible"
      }

      let uptime_str = case overview.uptime_sec {
        Some(uptime) -> private.format_uptime(uptime)
        None -> "❌"
      }

      let color = case overview.klippy_state {
        Some(Ready) -> color_green
        _ -> color_orange
      }

      let base =
        embed.new(
          title: miniprint_title,
          description: "🌡️ Température : "
            <> temp_str
            <> "\n🖥️ CPU : "
            <> cpu_str
            <> "  •  RAM : "
            <> mem_str
            <> "\n"
            <> storage_str
            <> "\n⏱️ Uptime Moonraker : `"
            <> uptime_str
            <> "`",
          color: color,
        )

      let with_power_warning = case overview.throttled {
        Some(throttled) if throttled.bits != 0 ->
          embed.add_field(
            base,
            name: "⚠️ Alimentation",
            value: "Anomalie détectée (vcgencmd `0x"
              <> string.lowercase(int.to_base16(throttled.bits))
              <> "`) — sous-tension ou bridage thermique probable",
            inline: False,
          )
        _ -> base
      }

      with_power_warning
      |> embed.add_field(
        name: "🌐 Mainsail / Moonraker",
        value: {
          case overview.mainsail_up {
            True -> "🟢"
            False -> "🔴"
          }
        }
          <> " Mainsail  •  "
          <> {
          case overview.moonraker_up {
            True -> "🟢"
            False -> "🔴"
          }
        }
          <> " Moonraker",
        inline: True,
      )
      |> embed.add_field(
        name: "🔩 Klipper",
        value: private.klippy_state_emoji(overview.klippy_state)
          <> " `"
          <> klippy_state_label(overview.klippy_state)
          <> "`",
        inline: True,
      )
      |> embed.add_field(
        name: "📷 Crowsnest",
        value: case overview.crowsnest_up {
          True -> "🟢 actif"
          False -> "🔴 injoignable"
        },
        inline: True,
      )
      |> embed.add_field(
        name: "🔒 VPN",
        value: miniprint_peer_line(peer),
        inline: False,
      )
    }
  }
}

fn klippy_state_label(state: Option(miniprint_types.KlippyState)) -> String {
  case state {
    Some(Ready) -> "ready"
    Some(miniprint_types.Startup) -> "startup"
    Some(miniprint_types.Shutdown) -> "shutdown"
    Some(miniprint_types.Error) -> "error"
    None -> "injoignable"
  }
}

fn miniprint_peer_line(peer: Option(PeerInfo)) -> String {
  case peer {
    None -> "❓ Peer non trouvé dans WG_PEERS"
    Some(p) -> {
      let hs = case p.last_handshake {
        Some(ts) -> format_date_fr(ts)
        None -> "jamais connecté"
      }
      let status = case p.connected {
        True -> "🟢 connecté"
        False -> "⚫ pas de handshake récent"
      }
      status <> "\nDernier handshake : `" <> hs <> "`"
    }
  }
}

// ── /overview ────────────────────────────────────────────────────────────

/// Port de build-overview-status-resources-embed.ts. Comme /status, échoue
/// entièrement si get_all_statuses échoue ; les ressources hôte/température/
/// stockage dégradent individuellement en "❌ indisponible".
pub fn build_overview_status_resources_embed(
  client: docker.Client,
) -> Result(embed.Embed, DockerError) {
  use statuses <- result.try(docker.get_all_statuses(client))

  let temp_str = case docker.get_rpi_temperature() {
    Ok(temp) ->
      private.temp_emoji(temp) <> " **" <> int.to_string(temp) <> "°C**"
    Error(_) -> "❌ indisponible"
  }

  let host_str = case docker.get_host_resources() {
    Ok(host) ->
      "CPU : `"
      <> float.to_string(host.cpu_percent)
      <> "%`  •  RAM : `"
      <> int.to_string(host.mem_used_mb)
      <> "/"
      <> int.to_string(host.mem_total_mb)
      <> " MB ("
      <> float.to_string(host.mem_percent)
      <> "%)`"
    Error(_) -> "❌ indisponible"
  }

  let storage_str = case docker.get_storage_usage() {
    Ok(storage) ->
      "💾 SD : `"
      <> float.to_string(storage.sd.used_gb)
      <> "/"
      <> float.to_string(storage.sd.total_gb)
      <> " GB ("
      <> float.to_string(storage.sd.percent)
      <> "%)`  •  SSD : `"
      <> float.to_string(storage.ssd.used_gb)
      <> "/"
      <> float.to_string(storage.ssd.total_gb)
      <> " GB ("
      <> float.to_string(storage.ssd.percent)
      <> "%)`"
    Error(_) -> "❌ indisponible"
  }

  let base =
    embed.new(
      title: "📊 Overview — Statut & Ressources",
      description: "🌡️ Température : "
        <> temp_str
        <> "\n🖥️ "
        <> host_str
        <> "\n"
        <> storage_str,
      color: color_blurple,
    )

  let with_fields =
    private.add_grouped_service_fields(base, monitored_services(), fn(service) {
      overview_field_value(client, statuses, service)
    })

  Ok(with_fields)
}

fn overview_field_value(
  client: docker.Client,
  statuses: List(ContainerStatus),
  service,
) {
  case list.find(statuses, fn(status) { status.name == service }) {
    Error(Nil) -> None
    Ok(status) -> {
      let state_part =
        private.render_container_state_line(status)
        <> "  •  🔁 "
        <> int.to_string(status.restart_count)

      let res_part = case status.state == "running" {
        False -> ""
        True ->
          case docker.get_resource_usage(client, service) {
            Ok(usage) ->
              "\nCPU `"
              <> float.to_string(usage.cpu_percent)
              <> "%` \nRAM `"
              <> int.to_string(usage.mem_usage_mb)
              <> "MB`"
            Error(_) -> ""
          }
      }

      Some(state_part <> res_part)
    }
  }
}

/// Port de build-overview-vpn-embed.ts. Contrairement à build_vpn_embed (qui
/// ne liste que les peers connectés, via get_connected_peers), celui-ci
/// prend tous les peers configurés (get_all_peers) et affiche un compteur.
pub fn build_overview_vpn_embed(peers: List(PeerInfo)) -> embed.Embed {
  case peers {
    [] ->
      embed.new(
        title: "🔒 Overview — Peers VPN",
        description: "Aucun peer configuré.",
        color: color_grey,
      )

    _ -> {
      let connected_count =
        list.filter(peers, fn(p) { p.connected }) |> list.length

      let base =
        embed.new(
          title: "🔒 Overview — Peers VPN",
          description: "**"
            <> int.to_string(connected_count)
            <> "/"
            <> int.to_string(list.length(peers))
            <> "** peer(s) connecté(s)",
          color: case connected_count > 0 {
            True -> color_green
            False -> color_grey
          },
        )

      list.fold(peers, base, fn(embed, peer) {
        let status_emoji = case peer.connected {
          True -> "🟢"
          False -> "⚫"
        }
        let handshake_str = case peer.last_handshake {
          Some(ts) -> format_date_fr(ts)
          None -> "jamais connecté"
        }

        embed.add_field(
          embed,
          name: status_emoji <> " " <> peer.name,
          value: "Dernier handshake :\n`" <> handshake_str <> "`",
          inline: True,
        )
      })
    }
  }
}
