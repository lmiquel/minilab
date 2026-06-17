import Dockerode from "dockerode";
import { ServiceName, SERVICES } from "./services-docker";

export type { ServiceName };
export { MONITORED_SERVICES, CONTROLLABLE_SERVICES } from "./services-docker";

export interface ContainerStatus {
  name: ServiceName;
  containerId: string;
  state: string;        // running | exited | restarting | …
  status: string;
  restartCount: number;
}

export interface ResourceUsage {
  cpuPercent: number;
  memUsageMB: number;
  memPercent: number;
}

class DockerManager {
  private docker: Dockerode;

  constructor() {
    this.docker = new Dockerode({ socketPath: "/var/run/docker.sock" });
  }

  /** Exécute une commande dans le conteneur WireGuard et retourne le stdout */
  async execInWireguard(cmd: string[]): Promise<string> {
    const container = this.docker.getContainer(SERVICES.wireguard.containerName);
    const exec = await container.exec({
      Cmd: cmd,
      AttachStdout: true,
      AttachStderr: false,
    });
    const stream = await exec.start({ hijack: true, stdin: false });
    return new Promise<string>((resolve) => {
      let data = "";
      stream.on("data", (chunk: Buffer) => (data += chunk.toString()));
      stream.on("end", () => resolve(data));
    });
  }

  /** Renvoie le statut d'un conteneur */
  async getStatus(service: ServiceName): Promise<ContainerStatus> {
    const container = this.docker.getContainer(SERVICES[service].containerName);
    const info = await container.inspect();

    return {
      name: service,
      containerId: info.Id.slice(0, 12),
      state: info.State.Status,
      status: info.State.Status,
      restartCount: info.RestartCount,
    };
  }

  /** Renvoie le statut de tous les services surveillés */
  async getAllStatuses(): Promise<ContainerStatus[]> {
    const { MONITORED_SERVICES } = await import("./services-docker");
    return Promise.all(MONITORED_SERVICES.map((s) => this.getStatus(s)));
  }

  /** Arrête proprement un service */
  async stopService(service: ServiceName): Promise<void> {
    const container = this.docker.getContainer(SERVICES[service].containerName);
    await container.stop({ t: 10 });
  }

  /** Démarre un service */
  async startService(service: ServiceName): Promise<void> {
    const container = this.docker.getContainer(SERVICES[service].containerName);
    await container.start();
  }

  /** Redémarre un service */
  async restartService(service: ServiceName): Promise<void> {
    const container = this.docker.getContainer(SERVICES[service].containerName);
    await container.restart({ t: 10 });
  }

  /** Récupère les stats CPU/RAM (snapshot instantané) */
  async getResourceUsage(service: ServiceName): Promise<ResourceUsage> {
    const container = this.docker.getContainer(SERVICES[service].containerName);

    return new Promise((resolve, reject) => {
      container.stats({ stream: false }, (err: Error | null, data: any) => {
        if (err) return reject(err);
        
        const cpuDelta =
          data.cpu_stats.cpu_usage.total_usage -
          data.precpu_stats.cpu_usage.total_usage;
        const systemDelta =
          data.cpu_stats.system_cpu_usage - data.precpu_stats.system_cpu_usage;
        const numCpus = data.cpu_stats.online_cpus || 4;
        const cpuPercent =
          systemDelta > 0 ? (cpuDelta / systemDelta) * numCpus * 100 : 0;

        // ← Correction : soustraction du cache pour la vraie RAM utilisée
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

  /** Lit la température du RPi en °C */
  async getRpiTemperature(): Promise<number> {
    const fs = await import("fs/promises");
    const raw = await fs.readFile("/sys/class/thermal/thermal_zone0/temp", "utf-8");
    return Math.round(parseInt(raw.trim(), 10) / 1000);
  }

  /** Vérifie si Docker répond */
  async ping(): Promise<boolean> {
    try {
      await this.docker.ping();
      return true;
    } catch {
      return false;
    }
  }
}

export const dockerManager = new DockerManager();