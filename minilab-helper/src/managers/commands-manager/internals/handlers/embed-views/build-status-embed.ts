import { Colors, EmbedBuilder } from "discord.js";
import { MONITORED_SERVICES } from "../../../../../dictionaries/docker-services-dictionary/derived/monitored-services";
import { dockerManager } from "../../../../docker-manager/docker-manager";
import { addGroupedServiceFields } from "../../helpers/add-grouped-service-fields";
import { renderContainerStateLine } from "../../helpers/render-container-state-line";

export async function buildStatusEmbed(): Promise<EmbedBuilder> {
  const statuses = await dockerManager.getAllStatuses();
  const statusMap = new Map(statuses.map((s) => [s.name, s]));

  const embed = new EmbedBuilder().setTitle("📊 Statut du minilab").setColor(Colors.Blurple).setTimestamp();

  await addGroupedServiceFields(embed, MONITORED_SERVICES, (service) => {
    const status = statusMap.get(service);
    if (!status) return null;
    return `${renderContainerStateLine(status)}  •  🔁 ${status.restartCount}`;
  });

  return embed;
}
