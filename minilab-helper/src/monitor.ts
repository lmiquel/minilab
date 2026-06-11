import { Client, User } from "discord.js";
import { dockerManager, ServiceName, ContainerStatus, MONITORED_SERVICES } from "./docker";

// Intervalle de polling en ms
const POLL_INTERVAL_MS = 60_000; // 1 minute

// Nombre de redémarrages max avant alerte
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
    // Premier check immédiat après 5 secondes
    setTimeout(() => this.poll(), 5_000);
  }

  stop(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  private async poll(): Promise<void> {
    if (!this.owner) return;

    let statuses: ContainerStatus[];
    try {
      statuses = await dockerManager.getAllStatuses();
    } catch (err) {
      console.error("[Monitor] Erreur Docker:", err);
      await this.dm(
        "⚠️ **Impossible de joindre le daemon Docker !**\n" +
        "Le monitoring est partiellement aveugle."
      );
      return;
    }

    for (const status of statuses) {
      await this.checkStatus(status);
    }
  }

  private async checkStatus(status: ContainerStatus): Promise<void> {
    const prev = this.states.get(status.name);

    if (!prev) {
      // Première observation — on enregistre sans alerter
      this.states.set(status.name, {
        lastState: status.state,
        lastRestartCount: status.restartCount,
        alertedRestart: false,
      });
      return;
    }

    const emoji = this.serviceEmoji(status.name);

    // ── Changement d'état ──────────────────────────────────────────────────────
    if (prev.lastState !== status.state) {
      if (status.state !== "running") {
        await this.dm(
          `${emoji} **${status.name.toUpperCase()}** vient de passer à l'état \`${status.state}\`\n` +
          `État précédent : \`${prev.lastState}\`\n` +
          `Redémarrages Docker : ${status.restartCount}`
        );
      } else if (prev.lastState !== "running") {
        // Récupération
        await this.dm(
          `✅ **${status.name.toUpperCase()}** est de nouveau \`running\` (était \`${prev.lastState}\`)`
        );
      }
      prev.lastState = status.state;
      prev.alertedRestart = false;
    }

    // ── Boucle de redémarrages ─────────────────────────────────────────────────
    if (
      status.restartCount > prev.lastRestartCount &&
      status.restartCount >= RESTART_ALERT_THRESHOLD &&
      !prev.alertedRestart
    ) {
      await this.dm(
        `🔁 **${status.name.toUpperCase()}** a redémarré **${status.restartCount} fois** depuis son lancement.\n` +
        `Il est peut-être dans une boucle de crash. Vérifie les logs :\n` +
        `\`docker logs --tail 50 ${status.name}\``
      );
      prev.alertedRestart = true;
    }
    prev.lastRestartCount = status.restartCount;

    this.states.set(status.name, prev);
  }

  /** Envoie un DM à l'owner */
  async dm(message: string): Promise<void> {
    if (!this.owner) return;
    try {
      await this.owner.send(message);
    } catch (err) {
      console.error("[Monitor] Erreur envoi DM:", err);
    }
  }

  private serviceEmoji(service: ServiceName): string {
    const emojis: Record<ServiceName, string> = {
      ragnarok: "⚔️",
      valheim: "🛡️",
      pihole: "🔵",
    };
    return emojis[service];
  }
}
