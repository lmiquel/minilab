import { dockerManager } from "../../docker-manager/docker-manager";
import type { WireGuardState } from "../types/wireguard-state";
import { extractPubkeys } from "./extract-pubkeys";

export async function loadPeerNames(state: WireGuardState, peers: string[]): Promise<void> {
  let raw: string;
  try {
    raw = await dockerManager.exec("wireguard", "wg show wg0 peers");
  } catch (err) {
    console.error("[WG] Impossible de récupérer les peers WireGuard:", err);
    return;
  }

  const pubkeys = extractPubkeys(raw);

  if (pubkeys.length !== peers.length) {
    console.warn(
      `[WG] Nombre de peers WireGuard (${pubkeys.length}) ≠ WG_PEERS (${peers.length}), vérifier la cohérence`
    );
  }

  for (let i = 0; i < Math.min(pubkeys.length, peers.length); i++) {
    state.peerNames.set(pubkeys[i], peers[i]);
    console.log(`[WG] Peer mappé: ${peers[i]} → ${pubkeys[i].slice(0, 10)}…`);
  }
}
