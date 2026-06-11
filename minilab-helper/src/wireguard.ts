import { exec } from "child_process";
import { promisify } from "util";
import { MonitorService } from "./monitor";

const execAsync = promisify(exec);

// Intervalle de scraping des logs WireGuard en ms
const WG_POLL_INTERVAL_MS = 15_000;

// Cache des peers déjà vus (pubkey → dernier handshake)
const seenHandshakes = new Map<string, number>();

// Map pubkey → nom lisible (renseignée au démarrage depuis les fichiers de conf)
const peerNames = new Map<string, string>();

export function loadPeerNames(peers: string[]): void {
  // peers = ["alice", "bob"] depuis WG_PEERS
  // Pour chaque peer, le fichier /config/peer_<name>/publickey contient la clé publique
  // On la lit de manière asynchrone au démarrage
  for (const peer of peers) {
    const path = `/config/peer_${peer}/publickey`;
    import("fs/promises")
      .then((fs) => fs.readFile(path, "utf-8"))
      .then((key) => {
        peerNames.set(key.trim(), peer);
        console.log(`[WG] Peer chargé: ${peer} → ${key.trim().slice(0, 10)}…`);
      })
      .catch(() => {
        console.warn(`[WG] Impossible de lire la clé de ${peer} (${path})`);
      });
  }
}

export function startWireGuardWatcher(monitor: MonitorService): void {
  setInterval(() => checkWireGuardHandshakes(monitor), WG_POLL_INTERVAL_MS);
  console.log("[WG] Watcher démarré (intervalle:", WG_POLL_INTERVAL_MS / 1000, "s)");
}

async function checkWireGuardHandshakes(monitor: MonitorService): Promise<void> {
  let output: string;
  try {
    // wg show wireguard0 latest-handshakes → "pubkey\ttimestamp"
    const { stdout } = await execAsync("wg show wireguard0 latest-handshakes 2>/dev/null");
    output = stdout;
  } catch {
    // WireGuard non accessible depuis ce conteneur (mode dégradé)
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

      // Nouveau handshake = quelqu'un vient de se connecter
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
