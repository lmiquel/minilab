import type { ServiceName } from "../types/service-name";
import { SERVICES } from "../docker-services-dictionary";

export function toDiscordChoices(services: ServiceName[]) {
  return services.map((s) => ({
    name: `${SERVICES[s].emoji}  ${SERVICES[s].label}`,
    value: s,
  }));
}
