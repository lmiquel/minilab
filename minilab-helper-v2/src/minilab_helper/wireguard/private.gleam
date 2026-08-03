import booklet
import discord_gleam/bot
import discord_gleam/discord/snowflake.{type Snowflake}
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set
import gleam/string
import logging
import minilab_helper/common.{type PeerInfo, PeerInfo}
import minilab_helper/dictionaries/docker_services.{Wireguard}
import minilab_helper/docker/public as docker
import minilab_helper/monitoring/public as monitoring
import minilab_helper/wireguard/types.{
  type ConnectedPeer, type WireGuardState, ConnectedPeer, WireGuardState,
}

// ── Extraction des pubkeys (pur) ─────────────────────────────────────────

/// Extrait les clés publiques WireGuard (base64, 44 caractères se terminant
/// par `=`) d'une sortie `wg show wg0 peers`, une par ligne. Remplace la
/// regex `^([A-Za-z0-9+/]{43}=)$` du v1.
pub fn extract_pubkeys(output: String) -> List(String) {
  output
  |> string.split("\n")
  |> list.filter(is_pubkey_line)
}

fn is_pubkey_line(line: String) -> Bool {
  let graphemes = string.to_graphemes(line)

  case list.length(graphemes) {
    44 ->
      case list.last(graphemes) {
        Ok("=") -> list.take(graphemes, 43) |> list.all(is_base64_char)
        _ -> False
      }
    _ -> False
  }
}

fn is_base64_char(char: String) -> Bool {
  case char {
    "+" | "/" -> True
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    "A"
    | "B"
    | "C"
    | "D"
    | "E"
    | "F"
    | "G"
    | "H"
    | "I"
    | "J"
    | "K"
    | "L"
    | "M"
    | "N"
    | "O"
    | "P"
    | "Q"
    | "R"
    | "S"
    | "T"
    | "U"
    | "V"
    | "W"
    | "X"
    | "Y"
    | "Z" -> True
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z" -> True
    _ -> False
  }
}

// ── Parsing des handshakes (pur) ─────────────────────────────────────────

/// Parse la sortie de `wg show wg0 latest-handshakes` (une ligne
/// `<pubkey><espaces><timestamp>` par peer) en paires (pubkey, timestamp
/// unix). Les lignes sans timestamp valide ou à `0` (jamais handshaké) sont
/// ignorées.
pub fn parse_handshakes(output: String) -> List(#(String, Int)) {
  output
  |> string.split("\n")
  |> list.filter_map(parse_line)
}

fn parse_line(line: String) -> Result(#(String, Int), Nil) {
  let parts =
    line
    |> string.replace("\t", " ")
    |> string.trim
    |> string.split(" ")
    |> list.filter(fn(part) { part != "" })

  case parts {
    [pubkey, ts_str, ..] -> {
      use ts <- result.try(int.parse(ts_str))
      case ts {
        0 -> Error(Nil)
        _ -> Ok(#(pubkey, ts))
      }
    }
    _ -> Error(Nil)
  }
}

// ── Diff pur (port fidèle de check-wireguard-handshakes.ts) ─────────────

/// 5 minutes sans handshake = déconnecté.
const peer_timeout_seconds = 300

/// Diff pur entre l'état WireGuard précédent et les handshakes lus à
/// l'instant `now` (timestamp unix, secondes) : renvoie le nouvel état et
/// les messages à envoyer en DM.
pub fn diff_handshakes(
  state: WireGuardState,
  handshakes: List(#(String, Int)),
  now: Int,
) -> #(WireGuardState, List(String)) {
  let #(final_state, alerts_reversed) =
    list.fold(handshakes, #(state, []), fn(acc, handshake) {
      let #(state, alerts) = acc
      let #(pubkey, ts) = handshake
      let #(new_state, alert) = diff_one(state, pubkey, ts, now)

      case alert {
        Some(message) -> #(new_state, [message, ..alerts])
        None -> #(new_state, alerts)
      }
    })

  #(final_state, list.reverse(alerts_reversed))
}

fn diff_one(
  state: WireGuardState,
  pubkey: String,
  ts: Int,
  now: Int,
) -> #(WireGuardState, Option(String)) {
  let peer_name = case dict.get(state.peer_names, pubkey) {
    Ok(name) -> name
    Error(Nil) -> "clé inconnue " <> string.slice(pubkey, 0, 10) <> "…"
  }
  let date = common.format_date_fr(ts)
  let was_connected = set.contains(state.connected_peers, pubkey)
  let is_connected = now - ts < peer_timeout_seconds

  case is_connected, was_connected {
    True, False -> #(
      WireGuardState(
        ..state,
        connected_peers: set.insert(state.connected_peers, pubkey),
        seen_handshakes: dict.insert(state.seen_handshakes, pubkey, ts),
      ),
      Some(
        "🟢 *Connexion VPN détectée :* **" <> peer_name <> "** [" <> date <> "]",
      ),
    )

    False, True -> #(
      WireGuardState(
        ..state,
        connected_peers: set.delete(state.connected_peers, pubkey),
      ),
      Some("🔴 *Déconnexion VPN :* **" <> peer_name <> "** [" <> date <> "]"),
    )

    _, _ -> #(
      WireGuardState(
        ..state,
        seen_handshakes: dict.insert(state.seen_handshakes, pubkey, ts),
      ),
      None,
    )
  }
}

// ── Cycles impurs (shells) ────────────────────────────────────────────────

/// Un cycle de vérification des handshakes WireGuard : lit l'état des
/// peers via `docker exec`, diffuse les alertes de connexion/déconnexion en
/// DM. Port de check-wireguard-handshakes.ts.
pub fn check_wireguard_handshakes(
  docker_client: docker.Client,
  state: booklet.Booklet(WireGuardState),
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
) -> Nil {
  case docker.exec(docker_client, Wireguard, "wg show wg0 latest-handshakes") {
    Error(err) ->
      logging.log(logging.Error, "[WG] Erreur exec: " <> string.inspect(err))

    Ok(raw) -> {
      let handshakes = parse_handshakes(raw)
      let now = common.now()
      let current_state = booklet.get(state)

      let #(new_state, alerts) = diff_handshakes(current_state, handshakes, now)

      booklet.set(state, new_state)
      list.each(alerts, fn(message) { monitoring.dm(bot, owner_id, message) })
    }
  }
}

/// Associe les pubkeys WireGuard (dans l'ordre renvoyé par
/// `wg show wg0 peers`) aux noms fournis via `WG_PEERS`, par position — même
/// hypothèse que le v1 : l'ordre doit correspondre. Port de load-peer-names.ts.
pub fn load_peer_names(
  docker_client: docker.Client,
  state: booklet.Booklet(WireGuardState),
  peers: List(String),
) -> Nil {
  case docker.exec(docker_client, Wireguard, "wg show wg0 peers") {
    Error(err) ->
      logging.log(
        logging.Error,
        "[WG] Impossible de récupérer les peers WireGuard: "
          <> string.inspect(err),
      )

    Ok(raw) -> {
      let pubkeys = extract_pubkeys(raw)

      case list.length(pubkeys) == list.length(peers) {
        True -> Nil
        False ->
          logging.log(
            logging.Warning,
            "[WG] Nombre de peers WireGuard ("
              <> int.to_string(list.length(pubkeys))
              <> ") ≠ WG_PEERS ("
              <> int.to_string(list.length(peers))
              <> "), vérifier la cohérence",
          )
      }

      list.zip(pubkeys, peers)
      |> list.each(fn(pair) {
        let #(pubkey, name) = pair
        booklet.update(state, fn(current) {
          WireGuardState(
            ..current,
            peer_names: dict.insert(current.peer_names, pubkey, name),
          )
        })
        logging.log(
          logging.Info,
          "[WG] Peer mappé: "
            <> name
            <> " → "
            <> string.slice(pubkey, 0, 10)
            <> "…",
        )
      })
      Nil
    }
  }
}

// ── Lectures pures ────────────────────────────────────────────────────────

pub fn get_all_peers(state: WireGuardState) -> List(PeerInfo) {
  state.peer_names
  |> dict.to_list
  |> list.map(fn(pair) {
    let #(pubkey, name) = pair
    PeerInfo(
      name: name,
      connected: set.contains(state.connected_peers, pubkey),
      last_handshake: dict.get(state.seen_handshakes, pubkey)
        |> option.from_result,
    )
  })
}

pub fn get_connected_peers(state: WireGuardState) -> List(ConnectedPeer) {
  state.connected_peers
  |> set.to_list
  |> list.map(fn(pubkey) {
    let name =
      dict.get(state.peer_names, pubkey)
      |> result.unwrap("clé inconnue " <> string.slice(pubkey, 0, 10) <> "…")
    let since = dict.get(state.seen_handshakes, pubkey) |> result.unwrap(0)
    ConnectedPeer(name: name, since: since)
  })
}
