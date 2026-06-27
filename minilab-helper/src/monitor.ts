import { Client, User } from "discord.js";
import { dockerManager, ContainerStatus } from "./docker";
import { ServiceName, SERVICES, MONITORED_SERVICES } from "./services-docker";

const POLL_INTERVAL_MS = 60_000;
const RESTART_ALERT_THRESHOLD = 3;

interface ServiceState {
  lastState: string;
  lastRestartCount: number;
  alertedRestart: boolean;
}

export class MonitorService {
  private client: Client;
  private owner: User | null = null;
  private states = new Map<ServiceName, ServiceState>();
  private timer: NodeJS.Timeout | null = null;

  constructor(client: Client) {
    this.client = client;
  }

  async init(): Promise<void> {
    const ownerId = process.env.DISCORD_OWNER_ID!;
    try {
      this.owner = await this.client.users.fetch(ownerId);
      console.log(`[Monitor] Owner DM channel ouvert avec ${this.owner.tag}`);
    } catch (err) {
      console.error("[Monitor] Impossible de récupérer l'owner Discord:", err);
    }
  }

  start(): void {
    console.log(
      "[Monitor] Démarrage du polling toutes les",
      POLL_INTERVAL_MS / 1000,
      "s — services surveillés :",
      MONITORED_SERVICES.join(", ")
    );
    this.timer = setInterval(() => this.poll(), POLL_INTERVAL_MS);
    setTimeout(() => this.poll(), 5_000);
  }

  stop(): void {
    if (this.timer) { clearInterval(this.timer); this.timer = null; }
  }

  private async poll(): Promise<void> {
    if (!this.owner) return;
    let statuses: ContainerStatus[];
    try {
      statuses = await dockerManager.getAllStatuses();
    } catch (err) {
      console.error("[Monitor] Erreur Docker:", err);
      await this.dm(`⚠️ **Une erreur docker est survenue !**\n**${err}**`);
      return;
    }
    for (const status of statuses) await this.checkStatus(status);
  }

  private async checkStatus(status: ContainerStatus): Promise<void> {
    const prev = this.states.get(status.name);
    const { emoji, label } = SERVICES[status.name];

    if (!prev) {
      this.states.set(status.name, {
        lastState: status.state,
        lastRestartCount: status.restartCount,
        alertedRestart: false,
      });
      return;
    }

    if (prev.lastState !== status.state) {
      if (status.state !== "running") {
        await this.dm(
          `${emoji} **${label}** vient de passer à l'état \`${status.state}\`\n` +
          `État précédent : \`${prev.lastState}\`\n` +
          `Redémarrages Docker : ${status.restartCount}`
        );
      } else if (prev.lastState !== "running") {
        await this.dm(`✅ **${label}** est de nouveau \`running\` (était \`${prev.lastState}\`)`);
      }
      prev.lastState = status.state;
      prev.alertedRestart = false;
    }

    if (
      status.restartCount > prev.lastRestartCount &&
      status.restartCount >= RESTART_ALERT_THRESHOLD &&
      !prev.alertedRestart
    ) {
      await this.dm(
        `🔁 **${label}** a redémarré **${status.restartCount} fois** depuis son lancement.\n` +
        `Il est peut-être dans une boucle de crash. Vérifie les logs :\n` +
        `\`docker logs --tail 50 ${SERVICES[status.name].containerName}\``
      );
      prev.alertedRestart = true;
    }
    prev.lastRestartCount = status.restartCount;
    this.states.set(status.name, prev);
  }

  async dm(message: string): Promise<void> {
    if (!this.owner) return;
    try {
      await this.owner.send(message);
    } catch (err) {
      console.error("[Monitor] Erreur envoi DM:", err);
    }
  }
}
