import type { ChatInputCommandInteraction } from "discord.js";
import { buildVpnEmbed } from "./embed-views/build-vpn-embed";

export async function handleVpn(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.deferReply({ ephemeral: true });
  const embed = buildVpnEmbed();
  await interaction.editReply({ embeds: [embed] });
}
