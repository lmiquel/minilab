import { MonitorService } from "./monitor";
import { dockerManager } from "./docker";

const WG_POLL_INTERVAL_MS = 15_000;
const WG_PEER_TIMEOUT_MS = 5 * 60 * 1000; // 5 min sans handshake = déconnecté

const seenHandshakes = new Map<string, number>(); // pubkey → timestamp dernier handshake
const connectedPeers = new Set<string>();          // pubkeys actuellement connectés
const peerNames = new Map<string, string>();        // pubkey → nom

// ─────────────────────────────────────────────────────────────────────────────
//  Utilitaires
// ─────────────────────────────────────────────────────────────────────────────

// Validation des clés publiques WireGuard (base64, exactement 44 chars)
function extractPubkeys(output: string): string[] {
  return [...output.matchAll(/^([A-Za-z0-9+/]{43}=)$/gm)].map((m) => m[1]);
}

// ─────────────────────────────────────────────────────────────────────────────
//  API publique
// ─────────────────────────────────────────────────────────────────────────────

export interface PeerInfo {
  name: string;
  connected: boolean;
  lastHandshake: Date | null; // null = jamais connecté
}

/** Retourne tous les peers configurés avec leur statut pour /overview */
export function getAllPeers(): PeerInfo[] {
  return Array.from(peerNames.entries()).map(([pubkey, name]) => {
    const ts = seenHandshakes.get(pubkey);
    const connected = connectedPeers.has(pubkey);
    return {
      name,
      connected,
      lastHandshake: ts ? new Date(ts * 1000) : null,
    };
  });
}

/** Retourne la liste des peers actuellement connectés, utilisable par /vpn */
export function getConnectedPeers(): { name: string; since: Date }[] {
  return Array.from(connectedPeers).map((pubkey) => ({
    name: peerNames.get(pubkey) ?? `clé inconnue ${pubkey.slice(0, 10)}…`,
    since: new Date((seenHandshakes.get(pubkey) ?? 0) * 1000),
  }));
}

// ─────────────────────────────────────────────────────────────────────────────
//  Chargement des noms de peers
// ─────────────────────────────────────────────────────────────────────────────

export async function loadPeerNames(peers: string[]): Promise<void> {
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
    peerNames.set(pubkeys[i], peers[i]);
    console.log(`[WG] Peer mappé: ${peers[i]} → ${pubkeys[i].slice(0, 10)}…`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Watcher
// ─────────────────────────────────────────────────────────────────────────────

export function startWireGuardWatcher(monitor: MonitorService): void {
  setInterval(() => checkWireGuardHandshakes(monitor), WG_POLL_INTERVAL_MS);
  console.log("[WG] Watcher démarré (intervalle:", WG_POLL_INTERVAL_MS / 1000, "s)");
}

async function checkWireGuardHandshakes(monitor: MonitorService): Promise<void> {
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

    const peerName = peerNames.get(pubkey) ?? `clé inconnue ${pubkey.slice(0, 10)}…`;
    const date = new Date(ts * 1000).toLocaleString("fr-FR", { timeZone: "Europe/Paris" });

    const wasConnected = connectedPeers.has(pubkey);
    const isConnected = now - ts * 1000 < WG_PEER_TIMEOUT_MS;

    if (isConnected && !wasConnected) {
      connectedPeers.add(pubkey);
      seenHandshakes.set(pubkey, ts);
      await monitor.dm(`🟢 *Connexion VPN détectée :* **${peerName}** [${date}]`);
    } else if (!isConnected && wasConnected) {
      connectedPeers.delete(pubkey);
      await monitor.dm(`🔴 *Déconnexion VPN :* **${peerName}** [${date}]`);
    } else {
      seenHandshakes.set(pubkey, ts);
    }
  }
}
