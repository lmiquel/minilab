import { dockerManager } from "../../docker-manager/docker-manager";
import { monitoringManager } from "../../monitoring-manager/monitoring-manager";
import type { WireGuardState } from "../types/wireguard-state";
import { formatDateFr } from "../../../commons/helpers/format-date-fr";

const WG_PEER_TIMEOUT_MS = 5 * 60 * 1000; // 5 min sans handshake = déconnecté

export async function checkWireGuardHandshakes(state: WireGuardState): Promise<void> {
  let raw: string;
  try {
    raw = await dockerManager.exec("wireguard", "wg show wg0 latest-handshakes");
  } catch (err) {
    console.error("[WG] Erreur exec:", err);
    return;
  }

  const now = Date.now();
  const lines = raw.split("\n").filter(Boolean);

  for (const line of lines) {
    const parts = line.trim().split(/\s+/);
    if (parts.length < 2) continue;

    const [pubkey, tsStr] = parts;
    const ts = parseInt(tsStr, 10);
    if (!ts || ts === 0) continue; // Pas encore de handshake

    const peerName = state.peerNames.get(pubkey) ?? `clé inconnue ${pubkey.slice(0, 10)}…`;
    const date = formatDateFr(new Date(ts * 1000));

    const wasConnected = state.connectedPeers.has(pubkey);
    const isConnected = now - ts * 1000 < WG_PEER_TIMEOUT_MS;

    if (isConnected && !wasConnected) {
      state.connectedPeers.add(pubkey);
      state.seenHandshakes.set(pubkey, ts);
      await monitoringManager.dm(`🟢 *Connexion VPN détectée :* **${peerName}** [${date}]`);
    } else if (!isConnected && wasConnected) {
      state.connectedPeers.delete(pubkey);
      await monitoringManager.dm(`🔴 *Déconnexion VPN :* **${peerName}** [${date}]`);
    } else {
      state.seenHandshakes.set(pubkey, ts);
    }
  }
}
