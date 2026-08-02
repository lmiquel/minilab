import type { ServiceName } from "../types/service-name";
import { SERVICES } from "../docker-services-dictionnary";

export const ALL_SERVICES = Object.keys(SERVICES) as ServiceName[];
