import * as DockerodeModule from "dockerode";
import Dockerode from "dockerode";
import { ServiceName, SERVICES } from "./services-docker";

export type { ServiceName };
export { MONITORED_SERVICES, CONTROLLABLE_SERVICES } from "./services-docker";

export type HealthStatus = "healthy" | "unhealthy" | "starting" | "none";

export interface ContainerStatus {
  name: ServiceName;
  containerId: string;
  state: string;        // running | exited | restarting | …
  status: string;
  restartCount: number;
  health: HealthStatus;
}

export interface ResourceUsage {
  cpuPercent: number;
  memUsageMB: number;
  memPercent: number;
}

export interface HostResources {
  cpuPercent: number;
  memUsedMB: number;
  memTotalMB: number;
  memPercent: number;
}

class DockerManager {
  private docker: Dockerode;

  constructor() {
    const dockerHost = process.env.DOCKER_HOST as string;
    const url = new URL(dockerHost);
    this.docker = new Dockerode({ host: url.hostname, port: Number(url.port) || 2375 });
  }

  /**
   * Exécute une commande dans un conteneur et retourne le stdout.
   *
   * Le stream Docker exec est multiplexé (format 8-byte header par frame).
   * On utilise demuxStream pour séparer stdout/stderr correctement,
   * en accumulant les chunks dans des PassThrough streams — ce qui évite toute
   * corruption binaire liée à chunk.toString() sur des données non-UTF8.
   */
  async exec(service: ServiceName, cmd: string): Promise<string> {
    const { PassThrough } = await import("stream");
 
    const container = this.docker.getContainer(SERVICES[service].containerName);
    const exec = await container.exec({
      Cmd: cmd.split(" "),
      AttachStdout: true,
      AttachStderr: true,
    });
 
    const stream = await exec.start({ hijack: true, stdin: false });
 
    return new Promise<string>((resolve, reject) => {
      const stdout = new PassThrough();
      const stderr = new PassThrough();
 
      const chunks: Buffer[] = [];
      stdout.on("data", (chunk: Buffer) => chunks.push(chunk));
 
      stream.on("error", reject);
      stdout.on("error", reject);
 
      stream.on("end", () => {
        resolve(Buffer.concat(chunks).toString("utf8"));
      });
 
      (container as any).modem.demuxStream(stream, stdout, stderr);
    });
  }
 
  /**
   * Retourne les logs récents d'un container sous forme de string.
   */
  async getLogs(service: ServiceName, tail = 50): Promise<string> {
    const container = this.docker.getContainer(SERVICES[service].containerName);
    const buffer = await container.logs({ stdout: true, stderr: true, tail }) as Buffer;
    return buffer.toString("utf8");
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
      health: (info.State.Health?.Status ?? "none") as HealthStatus,
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

  /**
  * Récupère la consommation CPU et RAM globale du RPi hôte.
  * Lit /proc/host/stat et /proc/host/meminfo montés depuis l'hôte.
  *
  * CPU : deux lectures de /proc/stat espacées de 500ms pour calculer
  * le delta (un snapshot instantané seul ne suffit pas).
  */
  async getHostResources(): Promise<HostResources> {
    const fs = await import("fs/promises");
 
    const readStat = async (): Promise<number[]> => {
      const raw = await fs.readFile("/proc/host/stat", "utf-8");
      const line = raw.split("\n").find((l) => l.startsWith("cpu "))!;
      return line.trim().split(/\s+/).slice(1).map(Number);
    };
 
    const calcCpu = (a: number[], b: number[]): number => {
      const totalA = a.reduce((s, v) => s + v, 0);
      const totalB = b.reduce((s, v) => s + v, 0);
      const idleA = a[3];
      const idleB = b[3];
      const totalDelta = totalB - totalA;
      const idleDelta = idleB - idleA;
      if (totalDelta === 0) return 0;
      return Math.round(((totalDelta - idleDelta) / totalDelta) * 1000) / 10;
    };
 
    const [stat1] = await Promise.all([readStat()]);
    await new Promise((res) => setTimeout(res, 500));
    const stat2 = await readStat();
    const cpuPercent = calcCpu(stat1, stat2);
 
    const memRaw = await fs.readFile("/proc/host/meminfo", "utf-8");
    const memLines = Object.fromEntries(
      memRaw.split("\n")
        .filter(Boolean)
        .map((l) => {
          const [key, val] = l.split(":");
          return [key.trim(), parseInt(val.trim(), 10)];
        })
    );
 
    const memTotalMB = Math.round(memLines["MemTotal"] / 1024);
    const memAvailMB = Math.round(memLines["MemAvailable"] / 1024);
    const memUsedMB  = memTotalMB - memAvailMB;
    const memPercent = Math.round((memUsedMB / memTotalMB) * 1000) / 10;
 
    return { cpuPercent, memUsedMB, memTotalMB, memPercent };
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
