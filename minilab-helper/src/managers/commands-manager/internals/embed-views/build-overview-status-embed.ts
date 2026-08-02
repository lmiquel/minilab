import { Colors, EmbedBuilder } from "discord.js";
import { ContainerStatus } from "../../../../commons/types/container-status";
import { ServiceName } from "../../../../commons/types/service-name";
import { groupByCategory } from "../../../../dictionnaries/docker-services-dictionnary/derived/group-by-category";
import { MONITORED_SERVICES } from "../../../../dictionnaries/docker-services-dictionnary/derived/monitored-services";
import { SERVICES } from "../../../../dictionnaries/docker-services-dictionnary/docker-services-dictionnary";
import { CATEGORY_LABELS } from "../../../../dictionnaries/service-categories-dictionnary/service-categories-dictionnary";
import { dockerManager } from "../../../docker-manager/docker-manager";
import { renderContainerStateLine } from "../helpers/render-container-state-line";
import { tempEmoji } from "../helpers/temp-emoji";

export async function buildOverviewStatusEmbed(): Promise<EmbedBuilder> {
  const [statuses, host, temp, storage] = await Promise.all([
    dockerManager.getAllStatuses(),
    dockerManager.getHostResources().catch(() => null),
    dockerManager.getRpiTemperature().catch(() => null),
    dockerManager.getStorageUsage().catch(() => null),
  ]);

  const statusMap = new Map<ServiceName, ContainerStatus>(statuses.map((s) => [s.name, s]));

  const tempStr = temp !== null ? `${tempEmoji(temp)} **${temp}°C**` : "❌ indisponible";

  const hostStr = host !== null
    ? `CPU : \`${host.cpuPercent}%\`  •  RAM : \`${host.memUsedMB}/${host.memTotalMB} MB (${host.memPercent}%)\``
    : "❌ indisponible";

  const storageStr = storage !== null
    ? `💾 SD : \`${storage.sd.usedGB}/${storage.sd.totalGB} GB (${storage.sd.percent}%)\`  •  SSD : \`${storage.ssd.usedGB}/${storage.ssd.totalGB} GB (${storage.ssd.percent}%)\``
    : "❌ indisponible";

  const embed = new EmbedBuilder()
    .setTitle("📊 Overview — Statut & Ressources")
    .setColor(Colors.Blurple)
    .setTimestamp()
    .setDescription(`🌡️ Température : ${tempStr}\n🖥️ ${hostStr}\n${storageStr}`);

  const grouped = groupByCategory(MONITORED_SERVICES);

  for (const [cat, services] of grouped) {
    embed.addFields({
      name: "​", // zero-width space pour satisfaire Discord (pas de field vide)
      value: `**${CATEGORY_LABELS[cat]}**`,
      inline: false,
    });

    for (const s of services) {
      const status = statusMap.get(s);
      const { emoji, label } = SERVICES[s];

      if (!status) continue;

      const statePart = renderContainerStateLine(status);

      let resPart = "";
      if (status.state === "running") {
        try {
          const res = await dockerManager.getResourceUsage(s);
          resPart = `\nCPU \`${res.cpuPercent}%\` \nRAM \`${res.memUsageMB}MB\``;
        } catch {
          resPart = "";
        }
      }

      embed.addFields({
        name: `${emoji} ${label}`,
        value: `${statePart}  •  🔁 ${status.restartCount}${resPart}`,
        inline: true,
      });
    }
  }

  return embed;
}
