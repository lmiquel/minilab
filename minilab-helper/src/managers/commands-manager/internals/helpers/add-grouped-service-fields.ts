import type { EmbedBuilder } from "discord.js";
import type { ServiceName } from "../../../../commons/types/service-name";
import { groupByCategory } from "../../../../dictionaries/docker-services-dictionary/derived/group-by-category";
import { SERVICES } from "../../../../dictionaries/docker-services-dictionary/docker-services-dictionary";
import { CATEGORY_LABELS } from "../../../../dictionaries/service-categories-dictionary/service-categories-dictionary";

export async function addGroupedServiceFields(
  embed: EmbedBuilder,
  services: ServiceName[],
  buildValue: (service: ServiceName) => Promise<string | null> | string | null
): Promise<void> {
  const grouped = groupByCategory(services);

  for (const [cat, servicesInCat] of grouped) {
    embed.addFields({
      name: "​", // zero-width space pour satisfaire Discord (pas de field vide)
      value: `**${CATEGORY_LABELS[cat]}**`,
      inline: false,
    });

    for (const service of servicesInCat) {
      const value = await buildValue(service);
      if (value === null) continue;

      const { emoji, label } = SERVICES[service];
      embed.addFields({ name: `${emoji} ${label}`, value, inline: true });
    }
  }
}
