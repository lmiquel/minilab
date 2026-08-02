import type { HostResources } from "../../../commons/types/host-resources";

async function readStat(): Promise<number[]> {
  const fs = await import("fs/promises");
  const raw = await fs.readFile("/host/stat", "utf-8");
  const line = raw.split("\n").find((l) => l.startsWith("cpu "))!;
  return line.trim().split(/\s+/).slice(1).map(Number);
}

function calcCpu(a: number[], b: number[]): number {
  const totalA = a.reduce((s, v) => s + v, 0);
  const totalB = b.reduce((s, v) => s + v, 0);
  const idleA = a[3];
  const idleB = b[3];
  const totalDelta = totalB - totalA;
  const idleDelta = idleB - idleA;
  if (totalDelta === 0) return 0;
  return Math.round(((totalDelta - idleDelta) / totalDelta) * 1000) / 10;
}

/**
 * Récupère la consommation CPU et RAM globale du RPi hôte.
 * Lit /host/stat et /host/meminfo montés depuis l'hôte.
 *
 * CPU : deux lectures espacées de 500ms pour calculer le delta
 * (un snapshot instantané seul ne suffit pas).
 */
export async function getHostResources(): Promise<HostResources> {
  const fs = await import("fs/promises");

  const stat1 = await readStat();
  await new Promise((res) => setTimeout(res, 500));
  const stat2 = await readStat();
  const cpuPercent = calcCpu(stat1, stat2);

  const memRaw = await fs.readFile("/host/meminfo", "utf-8");
  const memLines = Object.fromEntries(
    memRaw
      .split("\n")
      .filter(Boolean)
      .map((l) => {
        const [key, val] = l.split(":");
        return [key.trim(), parseInt(val.trim(), 10)];
      })
  );

  const memTotalMB = Math.round(memLines["MemTotal"] / 1024);
  const memAvailMB = Math.round(memLines["MemAvailable"] / 1024);
  const memUsedMB = memTotalMB - memAvailMB;
  const memPercent = Math.round((memUsedMB / memTotalMB) * 1000) / 10;

  return { cpuPercent, memUsedMB, memTotalMB, memPercent };
}
