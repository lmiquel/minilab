import type { ServiceDefinition } from "./types/service-definition";
import { ServiceCategory } from "../service-categories-dictionary/types/service-category";

export const SERVICES = {
  valheim: {
    containerName: "valheim",
    label:         "Valheim",
    emoji:         "🌲",
    category:      ServiceCategory.Game,
    controllable:  true,
    monitored:     true,
  },

  cobblemon: {
    containerName: "cobblemon",
    label:         "Cobblemon",
    emoji:         "🎊",
    category:      ServiceCategory.Game,
    controllable:  true,
    monitored:     true,
  },

  terraria: {
    containerName: "terraria",
    label:         "Terraria",
    emoji:         "⛏️",
    category:      ServiceCategory.Game,
    controllable:  true,
    monitored:     true,
  },

  pingvinshare: {
    containerName: "pingvin-share",
    label:         "Pingvin Share",
    emoji:         "🐧",
    category:      ServiceCategory.Apps,
    controllable:  true,
    monitored:     true,
  },

  rollerderbyscoreboard: {
    containerName: "rollerderbyscoreboard",
    label:         "Roller Derby Scoreboard (Carolina)",
    emoji:         "🛼",
    category:      ServiceCategory.Apps,
    controllable:  true,
    monitored:     true,
  },

  gitea: {
    containerName: "gitea",
    label:         "Gitea",
    emoji:         "🍵",
    category:      ServiceCategory.Apps,
    controllable:  true,
    monitored:     true,
  },

  minilabhelper: {
    containerName: "minilab-helper",
    label:         "Minilab Helper",
    emoji:         "🤖",
    category:      ServiceCategory.Apps,
    controllable:  false,
    monitored:     true,
  },

  dockersocketproxy: {
    containerName: "docker-socket-proxy",
    label:         "Docker Socket Proxy",
    emoji:         "🔌",
    category:      ServiceCategory.Utils,
    controllable:  false,
    monitored:     true,
  },

  githubrunner: {
    containerName: "github-runner",
    label:         "GitHub Runner",
    emoji:         "🐙",
    category:      ServiceCategory.Utils,
    controllable:  false,
    monitored:     true,
  },

  mariadb: {
    containerName: "mariadb",
    label:         "MariaDB",
    emoji:         "🦭",
    category:      ServiceCategory.Utils,
    controllable:  true,
    monitored:     true,
  },

  wireguard: {
    containerName: "wireguard",
    label:         "WireGuard",
    emoji:         "🔒",
    category:      ServiceCategory.Network,
    controllable:  false,
    monitored:     true,
  },

  pihole: {
    containerName: "pihole",
    label:         "Pi-hole",
    emoji:         "🕳️",
    category:      ServiceCategory.Network,
    controllable:  false,
    monitored:     true,
  },

  cloudflared: {
    containerName: "cloudflared",
    label:         "Cloudflared",
    emoji:         "☁️",
    category:      ServiceCategory.Network,
    controllable:  false,
    monitored:     true,
  },

  duckdns: {
    containerName: "duckdns",
    label:         "DuckDNS",
    emoji:         "🦆",
    category:      ServiceCategory.Network,
    controllable:  false,
    monitored:     true,
  },
} as const satisfies Record<string, ServiceDefinition>;
