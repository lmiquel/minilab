import { MonitorService } from "./monitor";
import { dockerManager } from "./docker";

const WG_POLL_INTERVAL_MS = 15_000;

const seenHandshakes = new Map<string, number>();
const peerNames = new Map<string, string>(); // pubkey → nom

export async function loadPeerNames(peers: string[]): Promise<void> {
  let output: string;
  try {
    output = await dockerManager.execInWireguard(["wg", "show", "wg0", "peers"]);
  } catch (err) {
    console.error("[WG] Impossible de récupérer les peers WireGuard:", err);
    return;
  }

  // `wg show wg0 peers` retourne une pubkey par ligne, dans le même ordre que wg0.conf
  // ce qui correspond à l'ordre de WG_PEERS
  const pubkeys = output.trim().split("\n").filter(Boolean);

  if (pubkeys.length !== peers.length) {
    console.warn(
      `[WG] Nombre de peers WireGuard (${pubkeys.length}) ≠ WG_PEERS (${peers.length}), vérifier la cohérence`
    );
  }

  for (let i = 0; i < Math.min(pubkeys.length, peers.length); i++) {
    peerNames.set(pubkeys[i].trim(), peers[i]);
    console.log(`[WG] Peer mappé: ${peers[i]} → ${pubkeys[i].trim().slice(0, 10)}…`);
  }
}

export function startWireGuardWatcher(monitor: MonitorService): void {
  setInterval(() => checkWireGuardHandshakes(monitor), WG_POLL_INTERVAL_MS);
  console.log("[WG] Watcher démarré (intervalle:", WG_POLL_INTERVAL_MS / 1000, "s)");
}

async function checkWireGuardHandshakes(monitor: MonitorService): Promise<void> {
  let output: string;
  try {
    output = await dockerManager.execInWireguard(["wg", "show", "wg0", "latest-handshakes"]);
  } catch (err) {
    console.error("[WG] Erreur exec:", err);
    return;
  }

  const lines = output.trim().split("\n").filter(Boolean);

  for (const line of lines) {
    const parts = line.split(/\s+/);
    if (parts.length < 2) continue;

    const [pubkey, tsStr] = parts;
    const ts = parseInt(tsStr, 10);
    if (!ts || ts === 0) continue; // Pas encore de handshake

    const prev = seenHandshakes.get(pubkey) ?? 0;
    if (ts > prev) {
      seenHandshakes.set(pubkey, ts);

      const peerName = peerNames.get(pubkey) ?? `clé inconnue ${pubkey.slice(0, 10)}…`;
      const date = new Date(ts * 1000).toLocaleString("fr-FR", {
        timeZone: "Europe/Paris",
      });

      await monitor.dm(
        `🔐 **Connexion VPN détectée**\n` +
        `👤 Peer : **${peerName}**\n` +
        `🕐 Heure : ${date}`
      );
    }
  }
}