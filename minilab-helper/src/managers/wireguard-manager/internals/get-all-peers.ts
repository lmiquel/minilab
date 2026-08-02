import type { PeerInfo } from "../../../commons/types/peer-info";
import type { WireGuardState } from "../types/wireguard-state";

export function getAllPeers(state: WireGuardState): PeerInfo[] {
  return Array.from(state.peerNames.entries()).map(([pubkey, name]) => {
    const ts = state.seenHandshakes.get(pubkey);
    const connected = state.connectedPeers.has(pubkey);
    return {
      name,
      connected,
      lastHandshake: ts ? new Date(ts * 1000) : null,
    };
  });
}
