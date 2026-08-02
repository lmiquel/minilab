import type { ServiceName } from "../../../commons/types/service-name";
import type { ContainerStatus } from "../../../commons/types/container-status";
import type { ServiceState } from "../types/service-state";
import { HealthStatus } from "../../../commons/types/health-status";
import { healthEmoji } from "../../../commons/helpers/health-emoji";
import { SERVICES } from "../../../dictionaries/docker-services-dictionary/docker-services-dictionary";

const RESTART_ALERT_THRESHOLD = 3;

export async function checkStatus(
  status: ContainerStatus,
  states: Map<ServiceName, ServiceState>,
  dm: (message: string) => Promise<void>,
  onCloudflaredRestarted: () => void
): Promise<void> {
  const prev = states.get(status.name);
  const { emoji, label } = SERVICES[status.name];

  if (!prev) {
    states.set(status.name, {
      lastState: status.state,
      lastHealth: status.health,
      lastRestartCount: status.restartCount,
      alertedRestart: false,
    });
    return;
  }

  // ── Changement d'état (running / exited / …) ──────────────────────────
  if (prev.lastState !== status.state) {
    if (status.state !== "running") {
      await dm(
        `${emoji} **${label}** vient de passer à l'état \`${status.state}\`\n` +
        `État précédent : \`${prev.lastState}\`\n` +
        `Redémarrages Docker : ${status.restartCount}`
      );
    } else if (prev.lastState !== "running") {
      await dm(`✅ **${label}** est de nouveau \`running\` (était \`${prev.lastState}\`)`);

      // Si cloudflared redémarre, on re-fetch la nouvelle URL du tunnel
      if (status.name === "cloudflared") {
        onCloudflaredRestarted();
      }
    }
    prev.lastState = status.state;
    prev.alertedRestart = false;
  }

  // ── Changement de santé (healthy / unhealthy / starting) ─────────────
  if (prev.lastHealth !== status.health && status.health !== HealthStatus.None) {
    if (status.health === HealthStatus.Unhealthy) {
      await dm(
        `${healthEmoji(status.health)} **${label}** est \`unhealthy\` !\n` +
        `Vérifie les logs : \`docker logs --tail 50 ${SERVICES[status.name].containerName}\``
      );
    } else if (status.health === HealthStatus.Healthy && prev.lastHealth === HealthStatus.Unhealthy) {
      await dm(`${healthEmoji(status.health)} **${label}** est de nouveau \`healthy\`.`);
    }
    prev.lastHealth = status.health;
  }

  // ── Boucle de crash ───────────────────────────────────────────────────
  if (
    status.restartCount > prev.lastRestartCount &&
    status.restartCount >= RESTART_ALERT_THRESHOLD &&
    !prev.alertedRestart
  ) {
    await dm(
      `🔁 **${label}** a redémarré **${status.restartCount} fois** depuis son lancement.\n` +
      `Il est peut-être dans une boucle de crash. Vérifie les logs :\n` +
      `\`docker logs --tail 50 ${SERVICES[status.name].containerName}\``
    );
    prev.alertedRestart = true;
  }
  prev.lastRestartCount = status.restartCount;
  states.set(status.name, prev);
}
