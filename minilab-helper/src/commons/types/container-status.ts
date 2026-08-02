import type { ServiceName } from "./service-name";
import type { HealthStatus } from "./health-status";

export interface ContainerStatus {
  name: ServiceName;
  containerId: string;
  state: string; // running | exited | restarting | …
  status: string;
  restartCount: number;
  health: HealthStatus;
}
