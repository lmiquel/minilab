import type { ChatInputCommandInteraction } from "discord.js";
import { buildStatusEmbed } from "./embed-views/build-status-embed";

export async function handleStatus(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.deferReply({ ephemeral: true });
  const embed = await buildStatusEmbed();
  await interaction.editReply({ embeds: [embed] });
}
