import type { PeerInfo } from "../../commons/types/peer-info";
import type { WireGuardState } from "./types/wireguard-state";
import type { ConnectedPeer } from "./types/connected-peer";
import { getAllPeers } from "./internals/get-all-peers";
import { getConnectedPeers } from "./internals/get-connected-peers";
import { loadPeerNames } from "./internals/load-peer-names";
import { checkWireGuardHandshakes } from "./internals/check-wireguard-handshakes";

const WG_POLL_INTERVAL_MS = 15_000;

class WireGuardManager {
  private state: WireGuardState = {
    seenHandshakes: new Map(),
    connectedPeers: new Set(),
    peerNames: new Map(),
  };
  private timer: NodeJS.Timeout | null = null;

  getAllPeers(): PeerInfo[] {
    return getAllPeers(this.state);
  }

  getConnectedPeers(): ConnectedPeer[] {
    return getConnectedPeers(this.state);
  }

  async loadPeerNames(peers: string[]): Promise<void> {
    await loadPeerNames(this.state, peers);
  }

  start(): void {
    this.timer = setInterval(() => checkWireGuardHandshakes(this.state), WG_POLL_INTERVAL_MS);
    console.log("[WG] Watcher démarré (intervalle:", WG_POLL_INTERVAL_MS / 1000, "s)");
  }
}

export const wireguardManager = new WireGuardManager();
