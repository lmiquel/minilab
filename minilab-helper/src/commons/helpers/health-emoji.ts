import type { HealthStatus } from "../types/health-status";

const HEALTH_EMOJI: Record<HealthStatus, string> = {
  healthy: "💚",
  unhealthy: "❤️‍🩹",
  starting: "⏳",
  none: "⬜",
};

export function healthEmoji(status: HealthStatus): string {
  return HEALTH_EMOJI[status];
}
