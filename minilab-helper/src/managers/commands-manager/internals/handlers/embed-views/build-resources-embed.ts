import { Colors, EmbedBuilder } from "discord.js";
import { groupByCategory } from "../../../../../dictionnaries/docker-services-dictionnary/derived/group-by-category";
import { MONITORED_SERVICES } from "../../../../../dictionnaries/docker-services-dictionnary/derived/monitored-services";
import { SERVICES } from "../../../../../dictionnaries/docker-services-dictionnary/docker-services-dictionnary";
import { CATEGORY_LABELS } from "../../../../../dictionnaries/service-categories-dictionnary/service-categories-dictionnary";
import { dockerManager } from "../../../../docker-manager/docker-manager";
import { tempEmoji } from "../../helpers/temp-emoji";

export async function buildResourcesEmbed(): Promise<EmbedBuilder> {
  const embed = new EmbedBuilder().setTitle("📈 Ressources CPU / RAM — minilab").setColor(Colors.Green).setTimestamp();

  // Température RPi
  try {
    const temp = await dockerManager.getRpiTemperature();
    embed.setDescription(`🌡️ Température RPi : ${tempEmoji(temp)} **${temp}°C**`);
  } catch {
    embed.setDescription("🌡️ Température RPi : ❌ indisponible");
  }

  const grouped = groupByCategory(MONITORED_SERVICES);

  for (const [cat, services] of grouped) {
    embed.addFields({
      name: "​", // zero-width space pour satisfaire Discord (pas de field vide)
      value: `**${CATEGORY_LABELS[cat]}**`,
      inline: false,
    });

    for (const service of services) {
      const { emoji, label } = SERVICES[service];
      try {
        const res = await dockerManager.getResourceUsage(service);
        embed.addFields({
          name: `${emoji} ${label}`,
          value: `CPU : \`${res.cpuPercent}%\`\n` + `RAM : \`${res.memUsageMB}MB (${res.memPercent}%)\``,
          inline: true,
        });
      } catch {
        embed.addFields({
          name: `${emoji} ${label}`,
          value: "❌ Stats indisponibles\n(conteneur arrêté ?)",
          inline: true,
        });
      }
    }
  }

  return embed;
}
