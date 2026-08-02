import { Colors, EmbedBuilder } from "discord.js";
import { formatDateFr } from "../../../../commons/helpers/format-date-fr";
import { wireguardManager } from "../../../wireguard-manager/wireguard-manager";

export function buildVpnEmbed(): EmbedBuilder {
  const peers = wireguardManager.getConnectedPeers();
  const embed = new EmbedBuilder()
    .setTitle("🔒 Peers VPN connectés")
    .setColor(peers.length > 0 ? Colors.Green : Colors.Grey)
    .setTimestamp();

  if (peers.length === 0) {
    embed.setDescription("Aucun peer connecté actuellement.");
  } else {
    for (const peer of peers) {
      embed.addFields({
        name: `🟢 ${peer.name}`,
        value: `Dernier handshake : \`${formatDateFr(peer.since)}\``,
        inline: false,
      });
    }
  }

  return embed;
}
