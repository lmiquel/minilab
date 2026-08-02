import { SERVICES } from "../docker-services-dictionnary";
import { ALL_SERVICES } from "./all-services";

export const MONITORED_SERVICES = ALL_SERVICES.filter((s) => SERVICES[s].monitored);
