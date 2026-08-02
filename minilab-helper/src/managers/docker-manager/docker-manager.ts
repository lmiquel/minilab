import type Dockerode from "dockerode";
import type { ContainerStatus } from "../../commons/types/container-status";
import type { HostResources } from "../../commons/types/host-resources";
import type { ResourceUsage } from "../../commons/types/resource-usage";
import type { ServiceName } from "../../commons/types/service-name";
import { createDockerClient } from "./internals/create-docker-client";
import { execInContainer } from "./internals/exec-in-container";
import { getAllStatuses } from "./internals/get-all-statuses";
import { getContainerLogs } from "./internals/get-container-logs";
import { getContainerStatus } from "./internals/get-container-status";
import { getHostResources } from "./internals/get-host-resources";
import { getResourceUsage } from "./internals/get-resource-usage";
import { getRpiTemperature } from "./internals/get-rpi-temperature";
import { getStorageUsage } from "./internals/get-storage-usage";
import { restartService } from "./internals/restart-service";
import { startService } from "./internals/start-service";
import { stopService } from "./internals/stop-service";
import type { HostStorageUsage } from "./types/host-storage-usage";

class DockerManager {
  private docker: Dockerode = createDockerClient();

  exec(service: ServiceName, cmd: string): Promise<string> {
    return execInContainer(this.docker, service, cmd);
  }

  getLogs(service: ServiceName, tail = 50): Promise<string> {
    return getContainerLogs(this.docker, service, tail);
  }

  getStatus(service: ServiceName): Promise<ContainerStatus> {
    return getContainerStatus(this.docker, service);
  }

  getAllStatuses(): Promise<ContainerStatus[]> {
    return getAllStatuses(this.docker);
  }

  stopService(service: ServiceName): Promise<void> {
    return stopService(this.docker, service);
  }

  startService(service: ServiceName): Promise<void> {
    return startService(this.docker, service);
  }

  restartService(service: ServiceName): Promise<void> {
    return restartService(this.docker, service);
  }

  getResourceUsage(service: ServiceName): Promise<ResourceUsage> {
    return getResourceUsage(this.docker, service);
  }

  getHostResources(): Promise<HostResources> {
    return getHostResources();
  }

  getStorageUsage(): Promise<HostStorageUsage> {
    return getStorageUsage();
  }

  getRpiTemperature(): Promise<number> {
    return getRpiTemperature();
  }
}

export const dockerManager = new DockerManager();
