import type { ChatInputCommandInteraction } from "discord.js";
import type { ServiceName } from "../../../commons/types/service-name";
import { dockerManager } from "../../docker-manager/docker-manager";
import { monitoringManager } from "../../monitoring-manager/monitoring-manager";
import { SERVICES } from "../../../dictionnaries/docker-services-dictionnary/docker-services-dictionnary";

export async function handleStart(interaction: ChatInputCommandInteraction): Promise<void> {
  const service = interaction.options.getString("service", true) as ServiceName;
  await interaction.deferReply({ ephemeral: true });

  await dockerManager.startService(service);
  const { emoji, label } = SERVICES[service];
  await interaction.editReply(`${emoji} **${label}** démarré avec succès.`);
  await monitoringManager.dm(`▶️ **${label}** a été démarré manuellement via Discord.`);
}
