import { Colors, EmbedBuilder } from "discord.js";
import { formatDateFr } from "../../../../commons/helpers/format-date-fr";
import { KlippyState } from "../../../../commons/types/klippy-state";
import { MiniPrintOverview } from "../../../../commons/types/miniprint-overview";
import { miniPrintManager } from "../../../miniprint-manager/miniprint-manager";
import { wireguardManager } from "../../../wireguard-manager/wireguard-manager";
import { formatUptime } from "../helpers/format-uptime";
import { klippyStateEmoji } from "../helpers/klippy-state-emoji";
import { tempEmoji } from "../helpers/temp-emoji";

export async function buildMiniPrintEmbed(): Promise<EmbedBuilder> {
  const data: MiniPrintOverview = await miniPrintManager.getOverview();
  const peer = wireguardManager.getAllPeers().find((p) => p.name === miniPrintManager.peerName);

  const peerLine = (): string => {
    if (!peer) return "❓ Peer non trouvé dans WG_PEERS";
    const hs = peer.lastHandshake ? formatDateFr(peer.lastHandshake) : "jamais connecté";
    return `${peer.connected ? "🟢 connecté" : "⚫ pas de handshake récent"}\nDernier handshake : \`${hs}\``;
  };

  const embed = new EmbedBuilder().setTitle("🖨️ MiniPrint — Statut & Ressources").setTimestamp();

  if (!data.reachable) {
    embed
      .setColor(Colors.Grey)
      .setDescription("❌ MiniPrint est injoignable (VPN down, ou Pi éteint).")
      .addFields({ name: "🔒 VPN", value: peerLine(), inline: false });
    return embed;
  }

  const tempStr = data.cpuTempC !== null ? `${tempEmoji(data.cpuTempC)} **${data.cpuTempC}°C**` : "❌ indisponible";

  const cpuStr = data.cpuPercent !== null ? `\`${data.cpuPercent}%\`` : "❌";

  const memStr = data.moonrakerMemMB !== null
    ? `Moonraker \`${data.moonrakerMemMB}MB\`${data.totalMemMB !== null ? ` • RAM totale \`${data.totalMemMB}MB\`` : ""}`
    : "❌ indisponible";

  const storageStr = data.storage
    ? `💾 \`${data.storage.usedGB}/${data.storage.totalGB} GB (${data.storage.percent}%)\``
    : "💾 ❌ indisponible";

  const uptimeStr = data.uptimeSec !== null ? formatUptime(data.uptimeSec) : "❌";

  embed
    .setColor(data.klippyState === KlippyState.Ready ? Colors.Green : Colors.Orange)
    .setDescription(
      `🌡️ Température : ${tempStr}\n` +
      `🖥️ CPU : ${cpuStr}  •  RAM : ${memStr}\n` +
      `${storageStr}\n` +
      `⏱️ Uptime Moonraker : \`${uptimeStr}\``
    );

  if (data.throttled && data.throttled.bits !== 0) {
    embed.addFields({
      name: "⚠️ Alimentation",
      value: `Anomalie détectée (vcgencmd \`0x${data.throttled.bits.toString(16)}\`) — sous-tension ou bridage thermique probable`,
      inline: false,
    });
  }

  embed.addFields(
    {
      name: "🌐 Mainsail / Moonraker",
      value: `${data.mainsailUp ? "🟢" : "🔴"} Mainsail  •  ${data.moonrakerUp ? "🟢" : "🔴"} Moonraker`,
      inline: true,
    },
    {
      name: "🔩 Klipper",
      value: `${klippyStateEmoji(data.klippyState)} \`${data.klippyState ?? "injoignable"}\``,
      inline: true,
    },
    {
      name: "📷 Crowsnest",
      value: data.crowsnestUp ? "🟢 actif" : "🔴 injoignable",
      inline: true,
    },
    {
      name: "🔒 VPN",
      value: peerLine(),
      inline: false,
    },
  );

  return embed;
}
