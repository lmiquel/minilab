import type { ServiceName } from "../types/service-name";
import { SERVICES } from "../docker-services-dictionary";

export const ALL_SERVICES = Object.keys(SERVICES) as ServiceName[];
