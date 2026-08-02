import { Client, GatewayIntentBits } from "discord.js";
import "dotenv/config";
import { commandsManager } from "./managers/commands-manager/commands-manager";
import { monitoringManager } from "./managers/monitoring-manager/monitoring-manager";
import { wireguardManager } from "./managers/wireguard-manager/wireguard-manager";

const REQUIRED_ENV = ["DISCORD_TOKEN", "DISCORD_OWNER_ID", "WG_PEERS"];
for (const key of REQUIRED_ENV) {
  if (!process.env[key]) {
    console.error(`[Bot] Variable d'environnement manquante : ${key}`);
    process.exit(1);
  }
}

const TOKEN = process.env.DISCORD_TOKEN!;
const PEERS = process.env.WG_PEERS!;

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.DirectMessages,
  ],
});

client.once("ready", async (readyClient) => {
  console.log(`[Bot] Connecté en tant que ${readyClient.user.tag}`);

  try {
    await commandsManager.registerCommands(TOKEN, readyClient.user.id);
  } catch (err) {
    console.error("[Bot] Erreur enregistrement commandes:", err);
  }

  await monitoringManager.init(client);

  const peers = (PEERS ?? "").split(",").map((p) => p.trim()).filter(Boolean);
  if (peers.length > 0) {
    await wireguardManager.loadPeerNames(peers);
  }

  monitoringManager.start();
  wireguardManager.start();

  await monitoringManager.dm(
    "✅ **minilab-helper démarré !**\n" +
    "Utilise `/overview` pour voir l'état des serveurs.\n" +
    "Commandes disponibles : `/status` `/vpn` `/resources` `/miniprint` `/stop` `/start` `/restart` `/shutdown`"
  );
});

commandsManager.setupCommandHandler(client);

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
