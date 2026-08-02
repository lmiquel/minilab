import type Dockerode from "dockerode";
import type { ContainerStatus } from "../../../commons/types/container-status";
import { MONITORED_SERVICES } from "../../../dictionaries/docker-services-dictionary/derived/monitored-services";
import { getContainerStatus } from "./get-container-status";

/** Renvoie le statut de tous les services surveillés */
export async function getAllStatuses(docker: Dockerode): Promise<ContainerStatus[]> {
  return Promise.all(MONITORED_SERVICES.map((s) => getContainerStatus(docker, s)));
}
