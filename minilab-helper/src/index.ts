import "dotenv/config";
import { Client, GatewayIntentBits } from "discord.js";
import { MonitorService } from "./monitor";
import { setupCommandHandler, registerCommands } from "./commands";
import { startWireGuardWatcher, loadPeerNames } from "./wireguard";

const REQUIRED_ENV = ["DISCORD_TOKEN", "DISCORD_OWNER_ID", "WG_PEERS"];
for (const key of REQUIRED_ENV) {
  if (!process.env[key]) {
    console.error(`[Bot] Variable d'environnement manquante : ${key}`);
    process.exit(1);
  }
}

const TOKEN = process.env.DISCORD_TOKEN!;
const OWNER_ID = process.env.DISCORD_OWNER_ID!;
const PEERS = process.env.WG_PEERS!;

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.DirectMessages,
  ],
});

const monitor = new MonitorService(client);

client.once("ready", async (readyClient) => {
  console.log(`[Bot] Connecté en tant que ${readyClient.user.tag}`);

  // Enregistrement des commandes slash
  try {
    await registerCommands(TOKEN, readyClient.user.id);
  } catch (err) {
    console.error("[Bot] Erreur enregistrement commandes:", err);
  }

  // Initialisation du monitor (récupère l'objet User de l'owner)
  await monitor.init();

  // Chargement des noms de peers WireGuard
  const peers = (PEERS ?? "").split(",").map((p) => p.trim()).filter(Boolean);
  console.log(PEERS)
  console.log(peers)
  if (peers.length > 0) {
    await loadPeerNames(peers);
  }

  // Démarrage des services de fond
  monitor.start();
  startWireGuardWatcher(monitor);

  // Message de démarrage à l'owner
  await monitor.dm(
    "✅ **minilab-helper démarré !**\n" +
    "Utilise `/status` pour voir l'état des serveurs.\n" +
    "Commandes disponibles : `/status` `/stop` `/start` `/restart` `/resources` `/shutdown`"
  );
});

// Gestion des commandes slash
setupCommandHandler(client, monitor);

// ─────────────────────────────────────────────────────────────────────────────
//  Gestion des erreurs non catchées
// ─────────────────────────────────────────────────────────────────────────────

process.on("unhandledRejection", (err) => {
  console.error("[Bot] Unhandled rejection:", err);
});

process.on("uncaughtException", (err) => {
  console.error("[Bot] Uncaught exception:", err);
});

// ─────────────────────────────────────────────────────────────────────────────
//  Connexion
// ─────────────────────────────────────────────────────────────────────────────

client.login(TOKEN).catch((err) => {
  console.error("[Bot] Impossible de se connecter à Discord:", err);
  process.exit(1);
});
