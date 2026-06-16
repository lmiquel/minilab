export type ServiceCategory = "game" | "network" | "other";

export interface ServiceDefinition {
  /** Nom du conteneur Docker (doit correspondre au container_name du compose) */
  containerName: string;
  /** Label lisible pour les messages Discord */
  label: string;
  /** Emoji Discord */
  emoji: string;
  /** Catégorie du service */
  category: ServiceCategory;
  /** Le service peut être démarré/arrêté manuellement via Discord */
  controllable: boolean;
  /** Le service est surveillé par le monitor */
  monitored: boolean;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Registre des services
// ─────────────────────────────────────────────────────────────────────────────

export const SERVICES = {
  valheim: {
    containerName: "valheim",
    label:         "Valheim",
    emoji:         "🌲",
    category:      "game",
    controllable:  true,
    monitored:     true,
  },

  mariadb: {
    containerName: "mariadb",
    label:         "MariaDB",
    emoji:         "🦭",
    category:      "other",
    controllable:  false,
    monitored:     true,
  },

  wireguard: {
    containerName: "wireguard",
    label:         "WireGuard",
    emoji:         "🔒",
    category:      "network",
    controllable:  false,
    monitored:     true,
  },

  pihole: {
    containerName: "pihole",
    label:         "Pi-hole",
    emoji:         "🌐",
    category:      "network",
    controllable:  false,
    monitored:     true,
  },

  duckdns: {
    containerName: "duckdns",
    label:         "DuckDNS",
    emoji:         "🦆",
    category:      "network",
    controllable:  false,
    monitored:     true,
  },
} as const satisfies Record<string, ServiceDefinition>;

export type ServiceName = keyof typeof SERVICES;

// ─────────────────────────────────────────────────────────────────────────────
//  Vues filtrées (recalculées à partir du registre, jamais dupliquées)
// ─────────────────────────────────────────────────────────────────────────────

export const ALL_SERVICES = Object.keys(SERVICES) as ServiceName[];

export const MONITORED_SERVICES = ALL_SERVICES.filter(
  (s) => SERVICES[s].monitored
);

export const CONTROLLABLE_SERVICES = ALL_SERVICES.filter(
  (s) => SERVICES[s].controllable
);

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────────────

export function getService(name: ServiceName): ServiceDefinition {
  return SERVICES[name];
}

export function toDiscordChoices(services: ServiceName[]) {
  return services.map((s) => ({
    name: `${SERVICES[s].emoji}  ${SERVICES[s].label}`,
    value: s,
  }));
}