import type { ChatInputCommandInteraction } from "discord.js";
import { buildMiniPrintEmbed } from "./embed-views/build-miniprint-embed";
import { buildOverviewStatusResourcesEmbed } from "./embed-views/build-overview-status-resources-embed";
import { buildOverviewVpnEmbed } from "./embed-views/build-overview-vpn-embed";
export async function handleOverview(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.deferReply({ ephemeral: true });

  const [embedStatus, embedMiniPrint] = await Promise.all([buildOverviewStatusResourcesEmbed(), buildMiniPrintEmbed()]);
  const embedVpn = buildOverviewVpnEmbed();

  await interaction.editReply({ embeds: [embedStatus, embedVpn, embedMiniPrint] });
}
