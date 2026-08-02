import { healthEmoji } from "../../../../commons/helpers/health-emoji";
import type { ContainerStatus } from "../../../../commons/types/container-status";
import { HealthStatus } from "../../../../commons/types/health-status";

/** Si healthcheck dispo → on affiche uniquement son résultat (running implicite).
 *  Si pas de healthcheck → on affiche l'état Docker. */
export function renderContainerStateLine(status: ContainerStatus): string {
  const isRunning = status.state === "running";
  const hasHealth = status.health !== HealthStatus.None;

  return hasHealth && isRunning
    ? `${healthEmoji(status.health)} \`${status.health}\``
    : `${isRunning ? "🟢" : "🔴"} \`${status.state}\``;
}
