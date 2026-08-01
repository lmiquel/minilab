const MINIPRINT_HOST = "mini.print";
const MOONRAKER_PORT = 7125;
const MAINSAIL_PORT = 80;
const CROWSNEST_PORT = 8080;
const FETCH_TIMEOUT_MS = 4_000;

export const MINIPRINT_PEER_NAME = "MiniPrint";

// ─────────────────────────────────────────────────────────────────────────────
//  Types
// ─────────────────────────────────────────────────────────────────────────────

export interface ThrottledState {
  bits: number;
  flags: string[];
}

export interface StorageInfo {
  usedGB: number;
  totalGB: number;
  freeGB: number;
  percent: number;
}

export interface MiniPrintOverview {
  /** true si Moonraker OU Mainsail a répondu (au moins un signe de vie) */
  reachable: boolean;

  cpuTempC: number | null;
  cpuPercent: number | null;
  moonrakerMemMB: number | null;
  totalMemMB: number | null;
  uptimeSec: number | null;
  /** État vcgencmd brut (sous-tension, bridage thermique…), null si indisponible */
  throttled: ThrottledState | null;
  storage: StorageInfo | null;

  mainsailUp: boolean;
  moonrakerUp: boolean;
  klippyConnected: boolean;
  /** "ready" | "startup" | "shutdown" | "error" | null si injoignable */
  klippyState: string | null;
  crowsnestUp: boolean;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers HTTP — jamais d'exception : tout échec renvoie null / false
// ─────────────────────────────────────────────────────────────────────────────

async function fetchJson<T>(url: string): Promise<T | null> {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(FETCH_TIMEOUT_MS) });
    if (!res.ok) return null;
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

/** Une réponse HTTP, même une erreur 4xx/5xx, prouve que le service écoute. */
async function checkReachable(url: string): Promise<boolean> {
  try {
    await fetch(url, { method: "GET", signal: AbortSignal.timeout(FETCH_TIMEOUT_MS) });
    return true;
  } catch {
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Formes des réponses Moonraker utilisées (sous-ensemble minimal)
// ─────────────────────────────────────────────────────────────────────────────

interface ServerInfoResult {
  klippy_connected: boolean;
  klippy_state: string;
}

interface ProcStatsResult {
  moonraker_stats: { time: number; cpu_usage: number; memory: number; mem_units: string }[];
  throttled_state: ThrottledState;
  cpu_temp: number;
  system_cpu_usage: Record<string, number>; // { cpu: <global %>, cpu0: …, cpu1: … }
  system_uptime: number;
}

interface SystemInfoResult {
  system_info: {
    cpu_info: { total_memory: number; memory_units: string };
  };
}

interface DirectoryResult {
  disk_usage: { total: number; used: number; free: number }; // en octets
}

// ─────────────────────────────────────────────────────────────────────────────
//  API publique
// ─────────────────────────────────────────────────────────────────────────────

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

  const storage: StorageInfo | null = directory
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
    klippyState: serverInfo?.result.klippy_state ?? null,
    crowsnestUp,
  };
}
