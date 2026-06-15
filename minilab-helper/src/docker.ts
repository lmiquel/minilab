import Dockerode from "dockerode";

export type ServiceName = /* "ragnarok" | */ "valheim" | "pihole";

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
  memLimitMB: number;
  memPercent: number;
}

// Map service → container name (doit correspondre aux container_name du docker-compose)
const SERVICE_CONTAINERS: Record<ServiceName, string> = {
  // ragnarok: "ragnarok",
  valheim: "valheim",
  pihole: "pihole",
};

// Services qu'on peut stopper/démarrer manuellement via Discord
// ragnarok-db est géré implicitement par l'arrêt de ragnarok
export const CONTROLLABLE_SERVICES: ServiceName[] = [/* "ragnarok", */ "valheim", "pihole"];

// Tous les services surveillés par le monitor
export const MONITORED_SERVICES: ServiceName[] = [/* "ragnarok", */ "valheim", "pihole"];

class DockerManager {
  private docker: Dockerode;

  constructor() {
    this.docker = new Dockerode({ socketPath: "/var/run/docker.sock" });
  }

  /** Exécute une commande dans le conteneur WireGuard et retourne le stdout */
  async execInWireguard(cmd: string[]): Promise<string> {
    const container = this.docker.getContainer("wireguard");
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
    const containerName = SERVICE_CONTAINERS[service];
    const container = this.docker.getContainer(containerName);
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
    return Promise.all(MONITORED_SERVICES.map((s) => this.getStatus(s)));
  }

  /** Arrête proprement un service */
  async stopService(service: ServiceName): Promise<void> {
    const container = this.docker.getContainer(SERVICE_CONTAINERS[service]);
    await container.stop({ t: 10 });
  }

  /** Démarre un service */
  async startService(service: ServiceName): Promise<void> {
    const container = this.docker.getContainer(SERVICE_CONTAINERS[service]);
    await container.start();
  }

  /** Redémarre un service */
  async restartService(service: ServiceName): Promise<void> {
    const container = this.docker.getContainer(SERVICE_CONTAINERS[service]);
    await container.restart({ t: 10 });
  }

  /** Récupère les stats CPU/RAM (snapshot instantané) */
  async getResourceUsage(service: ServiceName): Promise<ResourceUsage> {
    const container = this.docker.getContainer(SERVICE_CONTAINERS[service]);

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

        const memUsage = data.memory_stats.usage || 0;
        const memLimit = data.memory_stats.limit || 1;

        resolve({
          cpuPercent: Math.round(cpuPercent * 10) / 10,
          memUsageMB: Math.round(memUsage / 1024 / 1024),
          memLimitMB: Math.round(memLimit / 1024 / 1024),
          memPercent: Math.round((memUsage / memLimit) * 100 * 10) / 10,
        });
      });
    });
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