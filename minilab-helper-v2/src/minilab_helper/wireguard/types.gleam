import gleam/dict.{type Dict}
import gleam/set.{type Set}

pub type WireGuardState {
  WireGuardState(
    /// pubkey -> timestamp unix du dernier handshake connu
    seen_handshakes: Dict(String, Int),
    /// pubkeys actuellement connectés
    connected_peers: Set(String),
    /// pubkey -> nom (chargé depuis WG_PEERS)
    peer_names: Dict(String, String),
  )
}

pub fn new() -> WireGuardState {
  WireGuardState(
    seen_handshakes: dict.new(),
    connected_peers: set.new(),
    peer_names: dict.new(),
  )
}

pub type ConnectedPeer {
  ConnectedPeer(name: String, since: Int)
}
