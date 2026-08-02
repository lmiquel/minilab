import { Colors, EmbedBuilder } from "discord.js";
import { formatDateFr } from "../../../../../commons/helpers/format-date-fr";
import { wireguardManager } from "../../../../wireguard-manager/wireguard-manager";

export function buildOverviewVpnEmbed(): EmbedBuilder {
  const peers = wireguardManager.getAllPeers();
  const connectedCount = peers.filter((p) => p.connected).length;

  const embed = new EmbedBuilder()
    .setTitle("🔒 Overview — Peers VPN")
    .setColor(connectedCount > 0 ? Colors.Green : Colors.Grey)
    .setTimestamp()
    .setDescription(`**${connectedCount}/${peers.length}** peer(s) connecté(s)`);

  if (peers.length === 0) {
    embed.setDescription("Aucun peer configuré.");
  } else {
    for (const peer of peers) {
      const statusEmoji = peer.connected ? "🟢" : "⚫";
      const handshakeStr = peer.lastHandshake ? formatDateFr(peer.lastHandshake) : "jamais connecté";

      embed.addFields({
        name: `${statusEmoji} ${peer.name}`,
        value: `Dernier handshake :\n\`${handshakeStr}\``,
        inline: true,
      });
    }
  }

  return embed;
}
