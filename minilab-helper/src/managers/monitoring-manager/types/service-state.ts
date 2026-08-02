import type { HealthStatus } from "../../../commons/types/health-status";

export interface ServiceState {
  lastState: string;
  lastHealth: HealthStatus;
  lastRestartCount: number;
  alertedRestart: boolean;
}
