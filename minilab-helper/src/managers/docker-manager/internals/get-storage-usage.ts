import type { HostStorageInfo } from "../../../commons/types/host-storage-info";
import type { HostStorageUsage } from "../types/host-storage-usage";

async function statfsToInfo(path: string): Promise<HostStorageInfo> {
  const fs = await import("fs/promises");
  const s = await (fs as any).statfs(path);
  const totalGB = Math.round(((s.blocks * s.bsize) / 1024 / 1024 / 1024) * 10) / 10;
  const availGB = Math.round(((s.bavail * s.bsize) / 1024 / 1024 / 1024) * 10) / 10;
  const usedGB = Math.round((totalGB - availGB) * 10) / 10;
  const percent = Math.round((usedGB / totalGB) * 1000) / 10;
  return { usedGB, totalGB, percent };
}

/**
 * Récupère l'espace utilisé/total de la carte SD et du SSD.
 * Utilise fs.statfs() sur les points de montage montés depuis l'hôte.
 */
export async function getStorageUsage(): Promise<HostStorageUsage> {
  const [sd, ssd] = await Promise.all([statfsToInfo("/host/rootfs"), statfsToInfo("/host/ssd")]);
  return { sd, ssd };
}
