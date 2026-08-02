import type { ThrottledState } from "../../../commons/types/throttled-state";

export interface ProcStatsResult {
  moonraker_stats: { time: number; cpu_usage: number; memory: number; mem_units: string }[];
  throttled_state: ThrottledState;
  cpu_temp: number;
  system_cpu_usage: Record<string, number>; // { cpu: <global %>, cpu0: …, cpu1: … }
  system_uptime: number;
}
