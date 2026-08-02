import type { MiniPrintOverview } from "../../../commons/types/miniprint-overview";
import type { KlippyState } from "../../../commons/types/klippy-state";
import type { PrinterStorageInfo } from "../../../commons/types/printer-storage-info";
import type { ServerInfoResult } from "../types/server-info-result";
import type { ProcStatsResult } from "../types/proc-stats-result";
import type { SystemInfoResult } from "../types/system-info-result";
import type { DirectoryResult } from "../types/directory-result";
import { fetchJson } from "./fetch-json";
import { checkReachable } from "./check-reachable";

const MINIPRINT_HOST = "mini.print";
const MOONRAKER_PORT = 7125;
const MAINSAIL_PORT = 80;
const CROWSNEST_PORT = 8080;

export async function getMiniPrintOverview(): Promise<MiniPrintOverview> {
  const moonraker = `http://${MINIPRINT_HOST}:${MOONRAKER_PORT}`;

  const [serverInfo, procStats, systemInfo, directory, mainsailUp, crowsnestUp] = await Promise.all([
    fetchJson<{ result: ServerInfoResult }>(`${moonraker}/server/info`),
    fetchJson<{ result: ProcStatsResult }>(`${moonraker}/machine/proc_stats`),
    fetchJson<{ result: SystemInfoResult }>(`${moonraker}/machine/system_info`),
    // "gcodes" est une racine toujours présente, utilisée ici juste pour son disk_usage
    fetchJson<{ result: DirectoryResult }>(`${moonraker}/server/files/directory?path=gcodes`),
    checkReachable(`http://${MINIPRINT_HOST}:${MAINSAIL_PORT}/`),
    checkReachable(`http://${MINIPRINT_HOST}:${CROWSNEST_PORT}/`),
  ]);

  const moonrakerUp = serverInfo !== null;
  const latestMoonrakerStat = procStats?.result.moonraker_stats.at(-1) ?? null;

  const bytesToGB = (b: number) => Math.round((b / 1024 / 1024 / 1024) * 10) / 10;

  const storage: PrinterStorageInfo | null = directory
    ? {
        usedGB: bytesToGB(directory.result.disk_usage.used),
        totalGB: bytesToGB(directory.result.disk_usage.total),
        freeGB: bytesToGB(directory.result.disk_usage.free),
        percent: Math.round((directory.result.disk_usage.used / directory.result.disk_usage.total) * 1000) / 10,
      }
    : null;

  return {
    reachable: moonrakerUp || mainsailUp,

    cpuTempC: procStats?.result.cpu_temp ?? null,
    cpuPercent: procStats?.result.system_cpu_usage?.cpu ?? null,
    moonrakerMemMB: latestMoonrakerStat ? Math.round(latestMoonrakerStat.memory / 1024) : null,
    totalMemMB: systemInfo ? Math.round(systemInfo.result.system_info.cpu_info.total_memory / 1024) : null,
    uptimeSec: procStats?.result.system_uptime ?? null,
    throttled: procStats?.result.throttled_state ?? null,
    storage,

    mainsailUp,
    moonrakerUp,
    klippyConnected: serverInfo?.result.klippy_connected ?? false,
    klippyState: (serverInfo?.result.klippy_state as KlippyState | undefined) ?? null,
    crowsnestUp,
  };
}
