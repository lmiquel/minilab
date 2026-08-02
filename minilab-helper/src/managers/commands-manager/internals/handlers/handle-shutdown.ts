import { exec } from "child_process";
import type { ChatInputCommandInteraction } from "discord.js";
import { promisify } from "util";
import { ALL_SERVICES } from "../../../../dictionaries/docker-services-dictionary/derived/all-services";
import { dockerManager } from "../../../docker-manager/docker-manager";
import { monitoringManager } from "../../../monitoring-manager/monitoring-manager";

const execAsync = promisify(exec);

export async function handleShutdown(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.deferReply({ ephemeral: true });

  await interaction.editReply(
    "⚠️ **Extinction du Raspberry Pi dans 10 secondes…**\n" +
    "Tous les services sont arrêtés proprement avant l'extinction."
  );
  await monitoringManager.dm(
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
    try {
      await execAsync("sudo shutdown -h now");
    } catch (err) {
      console.error("[Shutdown] Erreur:", err);
    }
  }, 10_000);
}
