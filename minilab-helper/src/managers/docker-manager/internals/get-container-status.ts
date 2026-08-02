import type Dockerode from "dockerode";
import type { ServiceName } from "../../../commons/types/service-name";
import type { ContainerStatus } from "../../../commons/types/container-status";
import type { HealthStatus } from "../../../commons/types/health-status";
import { SERVICES } from "../../../dictionaries/docker-services-dictionary/docker-services-dictionary";

/** Renvoie le statut d'un conteneur */
export async function getContainerStatus(docker: Dockerode, service: ServiceName): Promise<ContainerStatus> {
  const container = docker.getContainer(SERVICES[service].containerName);
  const info = await container.inspect();

  return {
    name: service,
    containerId: info.Id.slice(0, 12),
    state: info.State.Status,
    status: info.State.Status,
    restartCount: info.RestartCount,
    health: (info.State.Health?.Status ?? "none") as HealthStatus,
  };
}
