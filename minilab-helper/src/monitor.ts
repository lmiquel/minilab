import { Client, User } from "discord.js";
import { dockerManager, ContainerStatus, HealthStatus } from "./docker";
import { ServiceName, SERVICES, MONITORED_SERVICES } from "./services-docker";

const POLL_INTERVAL_MS = 60_000;
const RESTART_ALERT_THRESHOLD = 3;

// Retry pour récupérer l'URL cloudflared (le tunnel peut mettre quelques secondes)
const CLOUDFLARE_URL_MAX_ATTEMPTS = 10;
const CLOUDFLARE_URL_RETRY_DELAY_MS = 3_000;
const CLOUDFLARE_URL_REGEX = /https:\/\/[a-z0-9-]+\.trycloudflare\.com/;

const HEALTH_EMOJI: Record<HealthStatus, string> = {
  healthy:   "💚",
  unhealthy: "❤️‍🩹",
  starting:  "⏳",
  none:      "⬜",
};

interface ServiceState {
  lastState: string;
  lastHealth: HealthStatus;
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
 
    // Récupération de l'URL du tunnel cloudflared en arrière-plan
    this.fetchAndNotifyCloudflaredUrl();
  }
 
  stop(): void {
    if (this.timer) { clearInterval(this.timer); this.timer = null; }
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  //  Cloudflared URL
  // ─────────────────────────────────────────────────────────────────────────
 
  private async fetchAndNotifyCloudflaredUrl(): Promise<void> {
    for (let attempt = 1; attempt <= CLOUDFLARE_URL_MAX_ATTEMPTS; attempt++) {
      try {
        const logs = await dockerManager.getLogs("cloudflared", 100);
        const match = logs.match(CLOUDFLARE_URL_REGEX);
 
        if (match) {
          await this.dm(`☁️ **Tunnel Cloudflare actif :**\n${match[0]}`);
          console.log(`[Monitor] URL cloudflared récupérée : ${match[0]}`);
          return;
        }
      } catch (err) {
        console.warn(`[Monitor] Tentative ${attempt}/${CLOUDFLARE_URL_MAX_ATTEMPTS} — cloudflared pas encore prêt:`, err);
      }
 
      if (attempt < CLOUDFLARE_URL_MAX_ATTEMPTS) {
        await new Promise((res) => setTimeout(res, CLOUDFLARE_URL_RETRY_DELAY_MS));
      }
    }
 
    console.error("[Monitor] Impossible de récupérer l'URL cloudflared après plusieurs tentatives.");
    await this.dm("☁️ **Tunnel Cloudflare :** URL introuvable dans les logs, vérifie manuellement.");
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  //  Polling des statuts
  // ─────────────────────────────────────────────────────────────────────────
 
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
        lastHealth: status.health,
        lastRestartCount: status.restartCount,
        alertedRestart: false,
      });
      return;
    }
 
    // ── Changement d'état (running / exited / …) ──────────────────────────
    if (prev.lastState !== status.state) {
      if (status.state !== "running") {
        await this.dm(
          `${emoji} **${label}** vient de passer à l'état \`${status.state}\`\n` +
          `État précédent : \`${prev.lastState}\`\n` +
          `Redémarrages Docker : ${status.restartCount}`
        );
      } else if (prev.lastState !== "running") {
        await this.dm(`✅ **${label}** est de nouveau \`running\` (était \`${prev.lastState}\`)`);
 
        // Si cloudflared redémarre, on re-fetch la nouvelle URL du tunnel
        if (status.name === "cloudflared") {
          this.fetchAndNotifyCloudflaredUrl();
        }
      }
      prev.lastState = status.state;
      prev.alertedRestart = false;
    }
 
    // ── Changement de santé (healthy / unhealthy / starting) ─────────────
    if (prev.lastHealth !== status.health && status.health !== "none") {
      const healthEmoji = HEALTH_EMOJI[status.health];
      if (status.health === "unhealthy") {
        await this.dm(
          `${healthEmoji} **${label}** est \`unhealthy\` !\n` +
          `Vérifie les logs : \`docker logs --tail 50 ${SERVICES[status.name].containerName}\``
        );
      } else if (status.health === "healthy" && prev.lastHealth === "unhealthy") {
        await this.dm(`${healthEmoji} **${label}** est de nouveau \`healthy\`.`);
      }
      prev.lastHealth = status.health;
    }
 
    // ── Boucle de crash ───────────────────────────────────────────────────
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
