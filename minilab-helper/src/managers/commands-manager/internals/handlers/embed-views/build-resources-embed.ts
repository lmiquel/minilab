import { Colors, EmbedBuilder } from "discord.js";
import { MONITORED_SERVICES } from "../../../../../dictionaries/docker-services-dictionary/derived/monitored-services";
import { dockerManager } from "../../../../docker-manager/docker-manager";
import { addGroupedServiceFields } from "../../helpers/add-grouped-service-fields";
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

  await addGroupedServiceFields(embed, MONITORED_SERVICES, async (service) => {
    try {
      const res = await dockerManager.getResourceUsage(service);
      return `CPU : \`${res.cpuPercent}%\`\n` + `RAM : \`${res.memUsageMB}MB (${res.memPercent}%)\``;
    } catch {
      return "❌ Stats indisponibles\n(conteneur arrêté ?)";
    }
  });

  return embed;
}
