import type Dockerode from "dockerode";
import type { ServiceName } from "../../../commons/types/service-name";
import { SERVICES } from "../../../dictionnaries/docker-services-dictionnary/docker-services-dictionnary";

/** Démarre un service */
export async function startService(docker: Dockerode, service: ServiceName): Promise<void> {
  const container = docker.getContainer(SERVICES[service].containerName);
  await container.start();
}
