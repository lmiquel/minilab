import {
  Client,
  REST,
  Routes,
  SlashCommandBuilder,
  ChatInputCommandInteraction,
  EmbedBuilder,
  Colors,
} from "discord.js";
import { exec } from "child_process";
import { promisify } from "util";
import { dockerManager, ServiceName, HealthStatus, ContainerStatus } from "./docker";
import { MonitorService } from "./monitor";
import {
  SERVICES,
  ALL_SERVICES,
  CONTROLLABLE_SERVICES,
  MONITORED_SERVICES,
  CATEGORY_LABELS,
  toDiscordChoices,
  groupByCategory,
} from "./services-docker";
import { getConnectedPeers, getAllPeers } from "./wireguard";

const execAsync = promisify(exec);
const OWNER_ID = process.env.DISCORD_OWNER_ID!;

const HEALTH_EMOJI: Record<HealthStatus, string> = {
  healthy:   "💚",
  unhealthy: "❤️‍🩹",
  starting:  "⏳",
  none:      "⬜",
};

// ─────────────────────────────────────────────────────────────────────────────
//  Définition des commandes slash
// ─────────────────────────────────────────────────────────────────────────────

const SERVICE_CHOICES = toDiscordChoices(CONTROLLABLE_SERVICES);

export const commands = [
  new SlashCommandBuilder()
    .setName("overview")
    .setDescription("Vue d'ensemble du minilab : statut, ressources et VPN"),

  new SlashCommandBuilder()
    .setName("status")
    .setDescription("Affiche le statut de tous les services minilab"),

  new SlashCommandBuilder()
    .setName("stop")
    .setDescription("Arrête un service")
    .addStringOption((opt) =>
      opt.setName("service").setDescription("Le service à arrêter").setRequired(true).addChoices(...SERVICE_CHOICES)
    ),

  new SlashCommandBuilder()
    .setName("start")
    .setDescription("Démarre un service")
    .addStringOption((opt) =>
      opt.setName("service").setDescription("Le service à démarrer").setRequired(true).addChoices(...SERVICE_CHOICES)
    ),

  new SlashCommandBuilder()
    .setName("restart")
    .setDescription("Redémarre un service")
    .addStringOption((opt) =>
      opt.setName("service").setDescription("Le service à redémarrer").setRequired(true).addChoices(...SERVICE_CHOICES)
    ),

  new SlashCommandBuilder()
    .setName("resources")
    .setDescription("Affiche la consommation CPU/RAM et la température du RPi"),

  new SlashCommandBuilder()
    .setName("vpn")
    .setDescription("Affiche les peers WireGuard actuellement connectés"),

  new SlashCommandBuilder()
    .setName("shutdown")
    .setDescription("⚠️  Éteint complètement le Raspberry Pi (arrête tous les services d'abord)"),
].map((cmd) => cmd.toJSON());

// ─────────────────────────────────────────────────────────────────────────────
//  Enregistrement des commandes slash auprès de Discord
// ─────────────────────────────────────────────────────────────────────────────

export async function registerCommands(token: string, clientId: string): Promise<void> {
  const rest = new REST({ version: "10" }).setToken(token);
  await rest.put(Routes.applicationCommands(clientId), { body: commands });
  console.log("[Commands] Commandes slash enregistrées globalement.");
}

// ─────────────────────────────────────────────────────────────────────────────
//  Guard : seul le propriétaire peut exécuter les commandes
// ─────────────────────────────────────────────────────────────────────────────

function isOwner(interaction: ChatInputCommandInteraction): boolean {
  return interaction.user.id === OWNER_ID;
}

async function rejectUnauthorized(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.reply({ content: "🚫 Tu n'es pas autorisé à utiliser cette commande.", ephemeral: true });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Handler principal des interactions
// ─────────────────────────────────────────────────────────────────────────────

export function setupCommandHandler(client: Client, monitor: MonitorService): void {
  client.on("interactionCreate", async (interaction) => {
    if (!interaction.isChatInputCommand()) return;
    if (!isOwner(interaction)) { await rejectUnauthorized(interaction); return; }

    try {
      switch (interaction.commandName) {
        case "overview":  await handleOverview(interaction);          break;
        case "status":    await handleStatus(interaction);            break;
        case "stop":      await handleStop(interaction, monitor);     break;
        case "start":     await handleStart(interaction, monitor);    break;
        case "restart":   await handleRestart(interaction, monitor);  break;
        case "resources": await handleResources(interaction);         break;
        case "vpn":       await handleVpn(interaction);               break;
        case "shutdown":  await handleShutdown(interaction, monitor); break;
      }
    } catch (err) {
      console.error(`[Commands] Erreur sur /${interaction.commandName}:`, err);
      const msg = "❌ Une erreur est survenue lors de l'exécution de la commande.";
      if (interaction.replied || interaction.deferred) await interaction.editReply(msg);
      else await interaction.reply({ content: msg, ephemeral: true });
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Implémentations des commandes
// ─────────────────────────────────────────────────────────────────────────────

async function handleOverview(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.deferReply({ ephemeral: true });

  const fmt = (d: Date) => d.toLocaleString("fr-FR", { timeZone: "Europe/Paris" });

  // ── Embed 1 : Statut & Ressources ────────────────────────────────────────

  const [statuses, host, temp, storage] = await Promise.all([
    dockerManager.getAllStatuses(),
    dockerManager.getHostResources().catch(() => null),
    dockerManager.getRpiTemperature().catch(() => null),
    dockerManager.getStorageUsage().catch(() => null),
  ]);

  const statusMap = new Map<ServiceName, ContainerStatus>(statuses.map((s) => [s.name, s]));

  const tempStr = temp !== null
    ? `${temp >= 70 ? "🔴" : temp >= 60 ? "🟡" : "🟢"} **${temp}°C**`
    : "❌ indisponible";

  const hostStr = host !== null
    ? `CPU : \`${host.cpuPercent}%\`  •  RAM : \`${host.memUsedMB}/${host.memTotalMB} MB (${host.memPercent}%)\``
    : "❌ indisponible";

  const storageStr = storage !== null
    ? `💾 SD : \`${storage.sd.usedGB}/${storage.sd.totalGB} GB (${storage.sd.percent}%)\`  •  SSD : \`${storage.ssd.usedGB}/${storage.ssd.totalGB} GB (${storage.ssd.percent}%)\``
    : "❌ indisponible";

  const embedStatus = new EmbedBuilder()
    .setTitle("📊 Overview — Statut & Ressources")
    .setColor(Colors.Blurple)
    .setTimestamp()
    .setDescription(`🌡️ Température : ${tempStr}\n🖥️ ${hostStr}\n${storageStr}`);

  const grouped = groupByCategory(MONITORED_SERVICES);

  for (const [cat, services] of grouped) {
    const lines: string[] = [];
    embedStatus.addFields({
      name: "​", // zero-width space pour satisfaire Discord (pas de field vide)
      value: `**${CATEGORY_LABELS[cat]}**`,
      inline: false,
    });

    for (const s of services) {
      const status = statusMap.get(s);
      const { emoji, label } = SERVICES[s];

      if (!status) continue;

      const isRunning = status.state === "running";
      const hasHealth = status.health !== "none";

      // Si healthcheck dispo → on affiche uniquement son résultat (running implicite)
      // Si pas de healthcheck → on affiche l'état Docker
      const statePart = hasHealth && isRunning
        ? `${HEALTH_EMOJI[status.health]} \`${status.health}\``
        : `${isRunning ? "🟢" : "🔴"} \`${status.state}\``;

      let resPart = "";
      if (isRunning) {
        try {
          const res = await dockerManager.getResourceUsage(s);
          resPart = `\nCPU \`${res.cpuPercent}%\` \nRAM \`${res.memUsageMB}MB\``;
        } catch {
          resPart = "";
        }
      }

      embedStatus.addFields({
        name: `${emoji} ${label}`,
        value: `${statePart}  •  🔁 ${status.restartCount}${resPart}`,
        inline: true,
      });
    }
  }

  // ── Embed 2 : VPN ────────────────────────────────────────────────────────

  const peers = getAllPeers();
  const connectedCount = peers.filter((p) => p.connected).length;

  const embedVpn = new EmbedBuilder()
    .setTitle("🔒 Overview — Peers VPN")
    .setColor(connectedCount > 0 ? Colors.Green : Colors.Grey)
    .setTimestamp()
    .setDescription(`**${connectedCount}/${peers.length}** peer(s) connecté(s)`);

  if (peers.length === 0) {
    embedVpn.setDescription("Aucun peer configuré.");
  } else {
    for (const peer of peers) {
      const statusEmoji = peer.connected ? "🟢" : "⚫";
      const handshakeStr = peer.lastHandshake
        ? fmt(peer.lastHandshake)
        : "jamais connecté";

      embedVpn.addFields({
        name: `${statusEmoji} ${peer.name}`,
        value: `Dernier handshake :\n\`${handshakeStr}\``,
        inline: true,
      });
    }
  }

  await interaction.editReply({ embeds: [embedStatus, embedVpn] });
}

async function handleStatus(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.deferReply({ ephemeral: true });

  const statuses = await dockerManager.getAllStatuses();
  const statusMap = new Map(statuses.map((s) => [s.name, s]));

  const embed = new EmbedBuilder()
    .setTitle("📊 Statut du minilab")
    .setColor(Colors.Blurple)
    .setTimestamp();

  const grouped = groupByCategory(MONITORED_SERVICES);

  for (const [cat, services] of grouped) {
    embed.addFields({
      name: "​", // zero-width space pour satisfaire Discord (pas de field vide)
      value: `**${CATEGORY_LABELS[cat]}**`,
      inline: false,
    });

    for (const s of services) {
      const status = statusMap.get(s);
      const { emoji, label } = SERVICES[s];
      if (!status) continue;

      const isRunning = status.state === "running";
      const hasHealth = status.health !== "none";

      const statePart = hasHealth && isRunning
        ? `${HEALTH_EMOJI[status.health]} \`${status.health}\``
        : `${isRunning ? "🟢" : "🔴"} \`${status.state}\``;
        
      embed.addFields({
        name: `${emoji} ${label}`,
        value: `${statePart}  •  🔁 ${status.restartCount}`,
        inline: true,
      });
    }
  }

  await interaction.editReply({ embeds: [embed] });
}

async function handleStop(interaction: ChatInputCommandInteraction, monitor: MonitorService): Promise<void> {
  const service = interaction.options.getString("service", true) as ServiceName;
  await interaction.deferReply({ ephemeral: true });

  if (SERVICES[service].category === "network") {
    await interaction.followUp({
      content: `⚠️ Arrêter **${SERVICES[service].label}** peut impacter les autres services.`,
      ephemeral: true,
    });
  }

  await dockerManager.stopService(service);
  const { emoji, label } = SERVICES[service];
  await interaction.editReply(`${emoji} **${label}** arrêté avec succès.`);
  await monitor.dm(`🛑 **${label}** a été arrêté manuellement via Discord.`);
}

async function handleStart(interaction: ChatInputCommandInteraction, monitor: MonitorService): Promise<void> {
  const service = interaction.options.getString("service", true) as ServiceName;
  await interaction.deferReply({ ephemeral: true });

  await dockerManager.startService(service);
  const { emoji, label } = SERVICES[service];
  await interaction.editReply(`${emoji} **${label}** démarré avec succès.`);
  await monitor.dm(`▶️ **${label}** a été démarré manuellement via Discord.`);
}

async function handleRestart(interaction: ChatInputCommandInteraction, monitor: MonitorService): Promise<void> {
  const service = interaction.options.getString("service", true) as ServiceName;
  await interaction.deferReply({ ephemeral: true });

  await dockerManager.restartService(service);
  const { emoji, label } = SERVICES[service];
  await interaction.editReply(`${emoji} **${label}** redémarré avec succès.`);
  await monitor.dm(`🔁 **${label}** a été redémarré manuellement via Discord.`);
}

async function handleResources(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.deferReply({ ephemeral: true });

  const embed = new EmbedBuilder()
    .setTitle("📈 Ressources CPU / RAM — minilab")
    .setColor(Colors.Green)
    .setTimestamp();

  // Température RPi
  try {
    const temp = await dockerManager.getRpiTemperature();
    const tempEmoji = temp >= 70 ? "🔴" : temp >= 60 ? "🟡" : "🟢";
    embed.setDescription(`🌡️ Température RPi : ${tempEmoji} **${temp}°C**`);
  } catch {
    embed.setDescription("🌡️ Température RPi : ❌ indisponible");
  }

  const grouped = groupByCategory(MONITORED_SERVICES);

  for (const [cat, services] of grouped) {
    embed.addFields({
      name: "​", // zero-width space pour satisfaire Discord (pas de field vide)
      value: `**${CATEGORY_LABELS[cat]}**`,
      inline: false,
    });

    for (const service of services) {
      const { emoji, label } = SERVICES[service];
      try {
        const res = await dockerManager.getResourceUsage(service);
        embed.addFields({
          name: `${emoji} ${label}`,
          value:
            `CPU : \`${res.cpuPercent}%\`\n` +
            `RAM : \`${res.memUsageMB}MB (${res.memPercent}%)\``,
          inline: true,
        });
      } catch {
        embed.addFields({
          name: `${emoji} ${label}`,
          value: "❌ Stats indisponibles\n(conteneur arrêté ?)",
          inline: true,
        });
      }
    }
  }

  await interaction.editReply({ embeds: [embed] });
}

async function handleVpn(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.deferReply({ ephemeral: true });

  const peers = getConnectedPeers();
  const embed = new EmbedBuilder()
    .setTitle("🔒 Peers VPN connectés")
    .setColor(peers.length > 0 ? Colors.Green : Colors.Grey)
    .setTimestamp();

  if (peers.length === 0) {
    embed.setDescription("Aucun peer connecté actuellement.");
  } else {
    for (const peer of peers) {
      const since = peer.since.toLocaleString("fr-FR", { timeZone: "Europe/Paris" });
      embed.addFields({
        name: `🟢 ${peer.name}`,
        value: `Dernier handshake : \`${since}\``,
        inline: false,
      });
    }
  }

  await interaction.editReply({ embeds: [embed] });
}

async function handleShutdown(interaction: ChatInputCommandInteraction, monitor: MonitorService): Promise<void> {
  await interaction.deferReply({ ephemeral: true });

  await interaction.editReply(
    "⚠️ **Extinction du Raspberry Pi dans 10 secondes…**\n" +
    "Tous les services sont arrêtés proprement avant l'extinction."
  );
  await monitor.dm(
    "🔴 **SHUTDOWN du Raspberry Pi déclenché via Discord.**\n" +
    "Arrêt propre de tous les services puis extinction dans 10 secondes."
  );

  for (const service of ALL_SERVICES) {
    try {
      await dockerManager.stopService(service);
      console.log(`[Shutdown] ${service} arrêté.`);
    } catch {
      // On continue même si un conteneur est déjà mort
    }
  }

  setTimeout(async () => {
    try { await execAsync("sudo shutdown -h now"); }
    catch (err) { console.error("[Shutdown] Erreur:", err); }
  }, 10_000);
}
