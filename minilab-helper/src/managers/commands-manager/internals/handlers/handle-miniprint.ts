import type { ChatInputCommandInteraction } from "discord.js";
import { buildMiniPrintEmbed } from "./embed-views/build-miniprint-embed";

export async function handleMiniPrint(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.deferReply({ ephemeral: true });
  const embed = await buildMiniPrintEmbed();
  await interaction.editReply({ embeds: [embed] });
}
