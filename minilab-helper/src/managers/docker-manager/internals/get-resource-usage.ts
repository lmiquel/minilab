import type Dockerode from "dockerode";
import type { ContainerStats } from "dockerode";
import type { ServiceName } from "../../../commons/types/service-name";
import type { ResourceUsage } from "../../../commons/types/resource-usage";
import { SERVICES } from "../../../dictionaries/docker-services-dictionary/docker-services-dictionary";

/** Récupère les stats CPU/RAM (snapshot instantané) */
export async function getResourceUsage(docker: Dockerode, service: ServiceName): Promise<ResourceUsage> {
  const container = docker.getContainer(SERVICES[service].containerName);

  return new Promise((resolve, reject) => {
    container.stats({ stream: false }, (err: Error | null, data?: ContainerStats) => {
      if (err) return reject(err);
      if (!data) return reject(new Error(`Pas de stats disponibles pour ${service}`));

      const cpuDelta = data.cpu_stats.cpu_usage.total_usage - data.precpu_stats.cpu_usage.total_usage;
      const systemDelta = data.cpu_stats.system_cpu_usage - data.precpu_stats.system_cpu_usage;
      const numCpus = data.cpu_stats.online_cpus || 4;
      const cpuPercent = systemDelta > 0 ? (cpuDelta / systemDelta) * numCpus * 100 : 0;

      // Soustraction du cache pour la vraie RAM utilisée
      const memUsage = (data.memory_stats.usage || 0) - (data.memory_stats.stats?.inactive_file || 0);
      const memLimit = data.memory_stats.limit || 1;

      resolve({
        cpuPercent: Math.round(cpuPercent * 10) / 10,
        memUsageMB: Math.round(memUsage / 1024 / 1024),
        memPercent: Math.round((memUsage / memLimit) * 100 * 10) / 10,
      });
    });
  });
}
