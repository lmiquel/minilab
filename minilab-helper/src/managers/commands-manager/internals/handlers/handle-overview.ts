import type { ChatInputCommandInteraction } from "discord.js";
import { buildOverviewStatusEmbed } from "./embed-views/build-overview-status-embed";
import { buildMiniPrintEmbed } from "./embed-views/build-miniprint-embed";
import { buildOverviewVpnEmbed } from "./embed-views/build-overview-vpn-embed";
export async function handleOverview(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.deferReply({ ephemeral: true });

  const [embedStatus, embedMiniPrint] = await Promise.all([buildOverviewStatusEmbed(), buildMiniPrintEmbed()]);
  const embedVpn = buildOverviewVpnEmbed();

  await interaction.editReply({ embeds: [embedStatus, embedVpn, embedMiniPrint] });
}
