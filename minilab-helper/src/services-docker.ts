export type ServiceCategory = "game" | "network" | "apps" | "utils";

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
//  Ordre d'affichage des catégories
// ─────────────────────────────────────────────────────────────────────────────

export const CATEGORY_ORDER: ServiceCategory[] = ["game", "apps", "utils", "network"];

export const CATEGORY_LABELS: Record<ServiceCategory, string> = {
  game:    "🎮 Jeux",
  apps:    "📦 Apps",
  utils:   "🔧 Utilitaires",
  network: "🌐 Réseau",
};

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

  cobblemon: {
    containerName: "cobblemon",
    label:         "Cobblemon",
    emoji:         "🎊​",
    category:      "game",
    controllable:  true,
    monitored:     true,
  },

  pingvinshare: {
    containerName: "pingvin-share",
    label:         "Pingvin Share",
    emoji:         "🐧",
    category:      "apps",
    controllable:  true,
    monitored:     true,
  },

  minilabhelper: {
    containerName: "minilab-helper",
    label:         "Minilab Helper",
    emoji:         "🤖",
    category:      "apps",
    controllable:  false,
    monitored:     true,
  },

  dockersocketproxy: {
    containerName: "docker-socket-proxy",
    label:         "Docker Socket Proxy",
    emoji:         "🔌",
    category:      "utils",
    controllable:  false,
    monitored:     true,
  },

  mariadb: {
    containerName: "mariadb",
    label:         "MariaDB",
    emoji:         "🦭",
    category:      "utils",
    controllable:  true,
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
    emoji:         "🕳️",
    category:      "network",
    controllable:  false,
    monitored:     true,
  },

  cloudflared: {
    containerName: "cloudflared",
    label:         "Cloudflared",
    emoji:         "☁️",
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

export function groupByCategory(services: ServiceName[]): Map<ServiceCategory, ServiceName[]> {
  const map = new Map<ServiceCategory, ServiceName[]>();
  for (const cat of CATEGORY_ORDER) map.set(cat, []);
  for (const s of services) {
    const cat = SERVICES[s].category;
    map.get(cat)!.push(s);
  }

  for (const [cat, list] of map) {
    if (list.length === 0) map.delete(cat);
  }

  return map;
}
