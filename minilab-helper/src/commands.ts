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
import { dockerManager, ServiceName } from "./docker";
import { MonitorService } from "./monitor";
import {
  SERVICES,
  ALL_SERVICES,
  CONTROLLABLE_SERVICES,
  MONITORED_SERVICES,
  toDiscordChoices,
} from "./services-docker";

const execAsync = promisify(exec);
const OWNER_ID = process.env.DISCORD_OWNER_ID!;

// ─────────────────────────────────────────────────────────────────────────────
//  Définition des commandes slash
// ─────────────────────────────────────────────────────────────────────────────

const SERVICE_CHOICES = toDiscordChoices(CONTROLLABLE_SERVICES);

export const commands = [
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
    .setDescription("Affiche la consommation CPU/RAM de tous les services"),

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
        case "status":    await handleStatus(interaction);            break;
        case "stop":      await handleStop(interaction, monitor);     break;
        case "start":     await handleStart(interaction, monitor);    break;
        case "restart":   await handleRestart(interaction, monitor);  break;
        case "resources": await handleResources(interaction);         break;
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

async function handleStatus(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.deferReply({ ephemeral: true });

  const statuses = await dockerManager.getAllStatuses();
  const embed = new EmbedBuilder()
    .setTitle("📊 Statut du minilab")
    .setColor(Colors.Blurple)
    .setTimestamp();

  for (const s of statuses) {
    const { emoji, label } = SERVICES[s.name];
    const stateEmoji = s.state === "running" ? "🟢" : "🔴";
    embed.addFields({
      name: `${emoji} ${label}`,
      value: `${stateEmoji} \`${s.state}\`  •  Redémarrages : ${s.restartCount}`,
      inline: false,
    });
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

  for (const service of MONITORED_SERVICES) {
    const { emoji, label } = SERVICES[service];
    try {
      const res = await dockerManager.getResourceUsage(service);
      embed.addFields({
        name: `${emoji} ${label}`,
        value:
          `CPU : \`${res.cpuPercent}%\`\n` +
          `RAM : \`${res.memUsageMB} MB / ${res.memLimitMB} MB\` (${res.memPercent}%)`,
        inline: true,
      });
    } catch {
      embed.addFields({
        name: `${emoji} ${label}`,
        value: "❌ Stats indisponibles (conteneur arrêté ?)",
        inline: true,
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