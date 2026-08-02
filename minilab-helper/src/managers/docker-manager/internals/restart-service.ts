import type Dockerode from "dockerode";
import type { ServiceName } from "../../../commons/types/service-name";
import { SERVICES } from "../../../dictionnaries/docker-services-dictionnary/docker-services-dictionnary";

/** Redémarre un service */
export async function restartService(docker: Dockerode, service: ServiceName): Promise<void> {
  const container = docker.getContainer(SERVICES[service].containerName);
  await container.restart({ t: 10 });
}
