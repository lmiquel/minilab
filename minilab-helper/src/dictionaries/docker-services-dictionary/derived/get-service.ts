import type { ServiceName } from "../types/service-name";
import type { ServiceDefinition } from "../types/service-definition";
import { SERVICES } from "../docker-services-dictionary";

export function getService(name: ServiceName): ServiceDefinition {
  return SERVICES[name];
}
