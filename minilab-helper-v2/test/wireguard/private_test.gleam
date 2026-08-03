import gleam/dict
import gleam/set
import minilab_helper/wireguard/private.{diff_handshakes, extract_pubkeys}
import minilab_helper/wireguard/types.{WireGuardState}

const now = 1_000_000

const pubkey = "PUBKEY"

fn state_with(peer_names, connected_peers, seen_handshakes) {
  WireGuardState(
    peer_names: dict.from_list(peer_names),
    connected_peers: set.from_list(connected_peers),
    seen_handshakes: dict.from_list(seen_handshakes),
  )
}

pub fn new_connection_alerts_and_updates_state_test() {
  let state = state_with([#(pubkey, "alice")], [], [])
  let #(new_state, alerts) = diff_handshakes(state, [#(pubkey, now)], now)

  assert alerts
    == ["🟢 *Connexion VPN détectée :* **alice** [12/01/1970 14:46:40]"]
  assert set.contains(new_state.connected_peers, pubkey)
  assert dict.get(new_state.seen_handshakes, pubkey) == Ok(now)
}

pub fn disconnection_alerts_but_does_not_update_seen_handshake_test() {
  let old_ts = now - 400
  let state = state_with([#(pubkey, "alice")], [pubkey], [#(pubkey, old_ts)])
  let #(new_state, alerts) = diff_handshakes(state, [#(pubkey, old_ts)], now)

  assert alerts == ["🔴 *Déconnexion VPN :* **alice** [12/01/1970 14:40:00]"]
  assert !set.contains(new_state.connected_peers, pubkey)
  // Fidèle au v1 : seen_handshakes n'est pas mis à jour dans cette branche.
  assert dict.get(new_state.seen_handshakes, pubkey) == Ok(old_ts)
}

pub fn still_connected_updates_seen_handshake_without_alert_test() {
  let state = state_with([#(pubkey, "alice")], [pubkey], [#(pubkey, now - 100)])
  let #(new_state, alerts) = diff_handshakes(state, [#(pubkey, now)], now)

  assert alerts == []
  assert set.contains(new_state.connected_peers, pubkey)
  assert dict.get(new_state.seen_handshakes, pubkey) == Ok(now)
}

pub fn still_disconnected_updates_seen_handshake_without_alert_test() {
  let old_ts = now - 1000
  let state = state_with([#(pubkey, "alice")], [], [#(pubkey, old_ts)])
  let #(new_state, alerts) = diff_handshakes(state, [#(pubkey, old_ts)], now)

  assert alerts == []
  assert !set.contains(new_state.connected_peers, pubkey)
  assert dict.get(new_state.seen_handshakes, pubkey) == Ok(old_ts)
}

pub fn unknown_peer_falls_back_to_truncated_pubkey_label_test() {
  let state = state_with([], [], [])
  let #(_state, alerts) = diff_handshakes(state, [#(pubkey, now)], now)

  assert alerts
    == [
      "🟢 *Connexion VPN détectée :* **clé inconnue PUBKEY…** [12/01/1970 14:46:40]",
    ]
}

pub fn extracts_only_valid_44_char_base64_lines_test() {
  let output =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ=\n"
    <> "too-short=\n"
    <> "not a pubkey line at all\n"
    <> "0123456789+/0123456789+/0123456789+/0123456=\n"

  assert extract_pubkeys(output)
    == [
      "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQ=",
      "0123456789+/0123456789+/0123456789+/0123456=",
    ]
}

pub fn empty_output_yields_no_pubkeys_test() {
  assert extract_pubkeys("") == []
}
