import type { ServiceName } from "../../../commons/types/service-name";
import type { ServiceState } from "../types/service-state";
import { dockerManager } from "../../docker-manager/docker-manager";
import { checkStatus } from "./check-status";

export async function pollStatuses(
  states: Map<ServiceName, ServiceState>,
  dm: (message: string) => Promise<void>,
  onCloudflaredRestarted: () => void
): Promise<void> {
  let statuses;
  try {
    statuses = await dockerManager.getAllStatuses();
  } catch (err) {
    console.error("[Monitor] Erreur Docker:", err);
    await dm(`⚠️ **Une erreur docker est survenue !**\n**${err}**`);
    return;
  }
  for (const status of statuses) await checkStatus(status, states, dm, onCloudflaredRestarted);
}
