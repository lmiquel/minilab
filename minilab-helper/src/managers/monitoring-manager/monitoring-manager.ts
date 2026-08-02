import type { Client, User } from "discord.js";
import type { ServiceName } from "../../commons/types/service-name";
import type { ServiceState } from "./types/service-state";
import { pollStatuses } from "./internals/poll-statuses";
import { fetchAndNotifyCloudflaredUrl } from "./internals/fetch-and-notify-cloudflared-url";

const POLL_INTERVAL_MS = 60_000;

class MonitoringManager {
  private owner: User | null = null;
  private states = new Map<ServiceName, ServiceState>();
  private timer: NodeJS.Timeout | null = null;

  async init(client: Client): Promise<void> {
    const ownerId = process.env.DISCORD_OWNER_ID!;
    try {
      this.owner = await client.users.fetch(ownerId);
      console.log(`[Monitor] Owner DM channel ouvert avec ${this.owner.tag}`);
    } catch (err) {
      console.error("[Monitor] Impossible de récupérer l'owner Discord:", err);
    }
  }

  start(): void {
    console.log("[Monitor] Démarrage du polling toutes les", POLL_INTERVAL_MS / 1000, "s");
    this.timer = setInterval(() => this.poll(), POLL_INTERVAL_MS);
    setTimeout(() => this.poll(), 5_000);

    fetchAndNotifyCloudflaredUrl(this.dm.bind(this));
  }

  private async poll(): Promise<void> {
    if (!this.owner) return;
    await pollStatuses(this.states, this.dm.bind(this), () => fetchAndNotifyCloudflaredUrl(this.dm.bind(this)));
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

export const monitoringManager = new MonitoringManager();
