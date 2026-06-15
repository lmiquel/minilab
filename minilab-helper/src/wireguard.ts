import { exec } from "child_process";
import { promisify } from "util";
import { MonitorService } from "./monitor";
import { dockerManager } from "./docker";

const execAsync = promisify(exec);

const WG_POLL_INTERVAL_MS = 15_000;

const seenHandshakes = new Map<string, number>();

const peerNames = new Map<string, string>();

export function loadPeerNames(peers: string[]): void {
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
    const wireguardContainer = await dockerManager.getWireguardContainer();

    const exec = await wireguardContainer.exec({
      Cmd: ["wg", "show", "wg0", "latest-handshakes"],
      AttachStdout: true,
      AttachStderr: false,
    });
    const stream = await exec.start({ hijack: true, stdin: false });
    
    const output = await new Promise<string>((resolve) => {
      let data = "";
      stream.on("data", (chunk: Buffer) => data += chunk.toString());
      stream.on("end", () => resolve(data));
    });
    const { stdout } = await execAsync("docker exec wireguard wg show wg0 latest-handshakes 2>/dev/null");
    output = stdout;
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
