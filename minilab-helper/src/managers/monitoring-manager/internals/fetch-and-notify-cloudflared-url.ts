import { dockerManager } from "../../docker-manager/docker-manager";

const CLOUDFLARE_URL_MAX_ATTEMPTS = 10;
const CLOUDFLARE_URL_RETRY_DELAY_MS = 3_000;
const CLOUDFLARE_URL_REGEX = /https:\/\/[a-z0-9-]+\.trycloudflare\.com/;

export async function fetchAndNotifyCloudflaredUrl(dm: (message: string) => Promise<void>): Promise<void> {
  for (let attempt = 1; attempt <= CLOUDFLARE_URL_MAX_ATTEMPTS; attempt++) {
    try {
      const logs = await dockerManager.getLogs("cloudflared", 100);
      const match = logs.match(CLOUDFLARE_URL_REGEX);

      if (match) {
        await dm(`☁️ **Tunnel Cloudflare actif :**\n${match[0]}`);
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
  await dm("☁️ **Tunnel Cloudflare :** URL introuvable dans les logs, vérifie manuellement.");
}
