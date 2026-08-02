import type { WireGuardState } from "../types/wireguard-state";
import type { ConnectedPeer } from "../types/connected-peer";

export function getConnectedPeers(state: WireGuardState): ConnectedPeer[] {
  return Array.from(state.connectedPeers).map((pubkey) => ({
    name: state.peerNames.get(pubkey) ?? `clé inconnue ${pubkey.slice(0, 10)}…`,
    since: new Date((state.seenHandshakes.get(pubkey) ?? 0) * 1000),
  }));
}
