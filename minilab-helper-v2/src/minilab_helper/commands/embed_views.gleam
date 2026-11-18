import discord_gleam/types/embed
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import minilab_helper/commons.{format_date_fr}
import minilab_helper/miniprint.{
  type KlippyState, type MiniPrintOverview, KlippyError, Ready, Shutdown,
  Startup,
}
import minilab_helper/wireguard.{type ConnectedPeer, type PeerInfo}

const color_green = 0x57F287

const color_orange = 0xE67E22

const color_grey = 0x95A5A6

// ── /vpn ─────────────────────────────────────────────────────────────────

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
          temp_emoji_float(temp) <> " **" <> float.to_string(temp) <> "°C**"
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
        Some(uptime) -> format_uptime(uptime)
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
        value: klippy_state_emoji(overview.klippy_state)
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

fn klippy_state_label(state: Option(KlippyState)) -> String {
  case state {
    Some(Ready) -> "ready"
    Some(Startup) -> "startup"
    Some(Shutdown) -> "shutdown"
    Some(KlippyError) -> "error"
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

// ── Rendu (helpers colocalisés depuis l'ancien commands/private.gleam) ────

pub fn temp_emoji_float(celsius: Float) -> String {
  case celsius >=. 70.0 {
    True -> "🔴"
    False ->
      case celsius >=. 60.0 {
        True -> "🟡"
        False -> "🟢"
      }
  }
}

pub fn klippy_state_emoji(state: Option(KlippyState)) -> String {
  case state {
    Some(Ready) -> "🟢"
    Some(Startup) -> "🟡"
    Some(Shutdown) -> "🔴"
    Some(KlippyError) -> "🔴"
    None -> "⚫"
  }
}

pub fn format_uptime(total_seconds: Int) -> String {
  let days = total_seconds / 86_400
  let hours = total_seconds % 86_400 / 3600
  let minutes = total_seconds % 3600 / 60

  case days > 0 {
    True -> int.to_string(days) <> "j " <> int.to_string(hours) <> "h"
    False ->
      case hours > 0 {
        True -> int.to_string(hours) <> "h " <> int.to_string(minutes) <> "min"
        False -> int.to_string(minutes) <> "min"
      }
  }
}
