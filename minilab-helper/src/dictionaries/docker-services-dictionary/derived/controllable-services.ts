import { SERVICES } from "../docker-services-dictionary";
import { ALL_SERVICES } from "./all-services";

export const CONTROLLABLE_SERVICES = ALL_SERVICES.filter((s) => SERVICES[s].controllable);
