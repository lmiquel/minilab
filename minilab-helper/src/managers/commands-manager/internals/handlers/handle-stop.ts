import type { ChatInputCommandInteraction } from "discord.js";
import type { ServiceName } from "../../../../commons/types/service-name";
import { dockerManager } from "../../../docker-manager/docker-manager";
import { monitoringManager } from "../../../monitoring-manager/monitoring-manager";
import { SERVICES } from "../../../../dictionnaries/docker-services-dictionnary/docker-services-dictionnary";
import { ServiceCategory } from "../../../../dictionnaries/service-categories-dictionnary/types/service-category";

export async function handleStop(interaction: ChatInputCommandInteraction): Promise<void> {
  const service = interaction.options.getString("service", true) as ServiceName;
  await interaction.deferReply({ ephemeral: true });

  if (SERVICES[service].category === ServiceCategory.Network) {
    await interaction.followUp({
      content: `⚠️ Arrêter **${SERVICES[service].label}** peut impacter les autres services.`,
      ephemeral: true,
    });
  }

  await dockerManager.stopService(service);
  const { emoji, label } = SERVICES[service];
  await interaction.editReply(`${emoji} **${label}** arrêté avec succès.`);
  await monitoringManager.dm(`🛑 **${label}** a été arrêté manuellement via Discord.`);
}
