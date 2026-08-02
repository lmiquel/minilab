import { Colors, EmbedBuilder } from "discord.js";
import { groupByCategory } from "../../../../../dictionnaries/docker-services-dictionnary/derived/group-by-category";
import { MONITORED_SERVICES } from "../../../../../dictionnaries/docker-services-dictionnary/derived/monitored-services";
import { SERVICES } from "../../../../../dictionnaries/docker-services-dictionnary/docker-services-dictionnary";
import { CATEGORY_LABELS } from "../../../../../dictionnaries/service-categories-dictionnary/service-categories-dictionnary";
import { dockerManager } from "../../../../docker-manager/docker-manager";
import { renderContainerStateLine } from "../../helpers/render-container-state-line";

export async function buildStatusEmbed(): Promise<EmbedBuilder> {
  const statuses = await dockerManager.getAllStatuses();
  const statusMap = new Map(statuses.map((s) => [s.name, s]));

  const embed = new EmbedBuilder().setTitle("📊 Statut du minilab").setColor(Colors.Blurple).setTimestamp();

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

      embed.addFields({
        name: `${emoji} ${label}`,
        value: `${renderContainerStateLine(status)}  •  🔁 ${status.restartCount}`,
        inline: true,
      });
    }
  }

  return embed;
}
