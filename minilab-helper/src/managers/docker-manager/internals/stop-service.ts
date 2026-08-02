import type Dockerode from "dockerode";
import type { ServiceName } from "../../../commons/types/service-name";
import { SERVICES } from "../../../dictionaries/docker-services-dictionary/docker-services-dictionary";

/** Arrête proprement un service */
export async function stopService(docker: Dockerode, service: ServiceName): Promise<void> {
  const container = docker.getContainer(SERVICES[service].containerName);
  await container.stop({ t: 10 });
}
