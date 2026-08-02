import { Colors, EmbedBuilder } from "discord.js";
import { MONITORED_SERVICES } from "../../../../../dictionaries/docker-services-dictionary/derived/monitored-services";
import { dockerManager } from "../../../../docker-manager/docker-manager";
import { addGroupedServiceFields } from "../../helpers/add-grouped-service-fields";
import { renderContainerStateLine } from "../../helpers/render-container-state-line";
import { tempEmoji } from "../../helpers/temp-emoji";

export async function buildOverviewStatusResourcesEmbed(): Promise<EmbedBuilder> {
  const [statuses, host, temp, storage] = await Promise.all([
    dockerManager.getAllStatuses(),
    dockerManager.getHostResources().catch(() => null),
    dockerManager.getRpiTemperature().catch(() => null),
    dockerManager.getStorageUsage().catch(() => null),
  ]);

  const statusMap = new Map(statuses.map((s) => [s.name, s]));

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

  await addGroupedServiceFields(embed, MONITORED_SERVICES, async (service) => {
    const status = statusMap.get(service);
    if (!status) return null;

    const statePart = renderContainerStateLine(status);

    let resPart = "";
    if (status.state === "running") {
      try {
        const res = await dockerManager.getResourceUsage(service);
        resPart = `\nCPU \`${res.cpuPercent}%\` \nRAM \`${res.memUsageMB}MB\``;
      } catch {
        resPart = "";
      }
    }

    return `${statePart}  •  🔁 ${status.restartCount}${resPart}`;
  });

  return embed;
}
