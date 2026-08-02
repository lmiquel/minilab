import type Dockerode from "dockerode";
import type { ServiceName } from "../../../commons/types/service-name";
import { SERVICES } from "../../../dictionaries/docker-services-dictionary/docker-services-dictionary";

/** Retourne les logs récents d'un container sous forme de string. */
export async function getContainerLogs(docker: Dockerode, service: ServiceName, tail = 50): Promise<string> {
  const container = docker.getContainer(SERVICES[service].containerName);
  const buffer = (await container.logs({ stdout: true, stderr: true, tail })) as Buffer;
  return buffer.toString("utf8");
}
