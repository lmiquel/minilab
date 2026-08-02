import type { ChatInputCommandInteraction } from "discord.js";
import { buildResourcesEmbed } from "./embed-views/build-resources-embed";

export async function handleResources(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.deferReply({ ephemeral: true });
  const embed = await buildResourcesEmbed();
  await interaction.editReply({ embeds: [embed] });
}
