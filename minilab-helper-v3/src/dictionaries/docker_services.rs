use super::service_categories::ServiceCategory;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ServiceName {
    Valheim,
    Cobblemon,
    Terraria,
    PingvinShare,
    RollerDerbyScoreboard,
    Gitea,
    MinilabHelper,
    DockerSocketProxy,
    GithubRunner,
    Mariadb,
    Wireguard,
    Pihole,
    Cloudflared,
    Duckdns,
    Backup,
}

pub struct ServiceDefinition {
    pub container_name: &'static str,
    pub label: &'static str,
    pub emoji: &'static str,
    pub category: ServiceCategory,
    pub controllable: bool,
    pub monitored: bool,
}

pub const ALL_SERVICES: [ServiceName; 15] = [
    ServiceName::Valheim,
    ServiceName::Cobblemon,
    ServiceName::Terraria,
    ServiceName::PingvinShare,
    ServiceName::RollerDerbyScoreboard,
    ServiceName::Gitea,
    ServiceName::MinilabHelper,
    ServiceName::DockerSocketProxy,
    ServiceName::GithubRunner,
    ServiceName::Mariadb,
    ServiceName::Wireguard,
    ServiceName::Pihole,
    ServiceName::Cloudflared,
    ServiceName::Duckdns,
    ServiceName::Backup,
];

impl ServiceName {
    pub fn definition(self) -> ServiceDefinition {
        use ServiceCategory::*;
        match self {
            ServiceName::Valheim => ServiceDefinition {
                container_name: "valheim",
                label: "Valheim",
                emoji: "🌲",
                category: Game,
                controllable: true,
                monitored: true,
            },
            ServiceName::Cobblemon => ServiceDefinition {
                container_name: "cobblemon",
                label: "Cobblemon",
                emoji: "🎊",
                category: Game,
                controllable: true,
                monitored: true,
            },
            ServiceName::Terraria => ServiceDefinition {
                container_name: "terraria",
                label: "Terraria",
                emoji: "⛏️",
                category: Game,
                controllable: true,
                monitored: true,
            },
            ServiceName::PingvinShare => ServiceDefinition {
                container_name: "pingvin-share",
                label: "Pingvin Share",
                emoji: "🐧",
                category: Apps,
                controllable: true,
                monitored: true,
            },
            ServiceName::RollerDerbyScoreboard => ServiceDefinition {
                container_name: "rollerderbyscoreboard",
                label: "RD Scoreboard",
                emoji: "🛼",
                category: Apps,
                controllable: true,
                monitored: true,
            },
            ServiceName::Gitea => ServiceDefinition {
                container_name: "gitea",
                label: "Gitea",
                emoji: "🍵",
                category: DevTools,
                controllable: true,
                monitored: true,
            },
            ServiceName::MinilabHelper => ServiceDefinition {
                container_name: "minilab-helper-v3",
                label: "Minilab Helper",
                emoji: "🤖",
                category: Apps,
                controllable: false,
                monitored: true,
            },
            ServiceName::DockerSocketProxy => ServiceDefinition {
                container_name: "docker-socket-proxy",
                label: "Docker Socket Proxy",
                emoji: "🔌",
                category: Utils,
                controllable: false,
                monitored: true,
            },
            ServiceName::GithubRunner => ServiceDefinition {
                container_name: "github-runner",
                label: "GitHub Runner",
                emoji: "🐙",
                category: DevTools,
                controllable: false,
                monitored: true,
            },
            ServiceName::Mariadb => ServiceDefinition {
                container_name: "mariadb",
                label: "MariaDB",
                emoji: "🦭",
                category: DevTools,
                controllable: true,
                monitored: true,
            },
            ServiceName::Wireguard => ServiceDefinition {
                container_name: "wireguard",
                label: "WireGuard",
                emoji: "🔒",
                category: Network,
                controllable: false,
                monitored: true,
            },
            ServiceName::Pihole => ServiceDefinition {
                container_name: "pihole",
                label: "Pi-hole",
                emoji: "🕳️",
                category: Network,
                controllable: false,
                monitored: true,
            },
            ServiceName::Cloudflared => ServiceDefinition {
                container_name: "cloudflared",
                label: "Cloudflared",
                emoji: "☁️",
                category: Network,
                controllable: false,
                monitored: true,
            },
            ServiceName::Duckdns => ServiceDefinition {
                container_name: "duckdns",
                label: "DuckDNS",
                emoji: "🦆",
                category: Network,
                controllable: false,
                monitored: true,
            },
            ServiceName::Backup => ServiceDefinition {
                container_name: "backup",
                label: "Backup",
                emoji: "💾",
                category: Utils,
                controllable: false,
                monitored: true,
            },
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            ServiceName::Valheim => "valheim",
            ServiceName::Cobblemon => "cobblemon",
            ServiceName::Terraria => "terraria",
            ServiceName::PingvinShare => "pingvinshare",
            ServiceName::RollerDerbyScoreboard => "rollerderbyscoreboard",
            ServiceName::Gitea => "gitea",
            ServiceName::MinilabHelper => "minilabhelper",
            ServiceName::DockerSocketProxy => "dockersocketproxy",
            ServiceName::GithubRunner => "githubrunner",
            ServiceName::Mariadb => "mariadb",
            ServiceName::Wireguard => "wireguard",
            ServiceName::Pihole => "pihole",
            ServiceName::Cloudflared => "cloudflared",
            ServiceName::Duckdns => "duckdns",
            ServiceName::Backup => "backup",
        }
    }

    pub fn from_str(value: &str) -> Option<ServiceName> {
        match value {
            "valheim" => Some(ServiceName::Valheim),
            "cobblemon" => Some(ServiceName::Cobblemon),
            "terraria" => Some(ServiceName::Terraria),
            "pingvinshare" => Some(ServiceName::PingvinShare),
            "rollerderbyscoreboard" => Some(ServiceName::RollerDerbyScoreboard),
            "gitea" => Some(ServiceName::Gitea),
            "minilabhelper" => Some(ServiceName::MinilabHelper),
            "dockersocketproxy" => Some(ServiceName::DockerSocketProxy),
            "githubrunner" => Some(ServiceName::GithubRunner),
            "mariadb" => Some(ServiceName::Mariadb),
            "wireguard" => Some(ServiceName::Wireguard),
            "pihole" => Some(ServiceName::Pihole),
            "cloudflared" => Some(ServiceName::Cloudflared),
            "duckdns" => Some(ServiceName::Duckdns),
            "backup" => Some(ServiceName::Backup),
            _ => None,
        }
    }
}

pub fn monitored_services() -> Vec<ServiceName> {
    ALL_SERVICES
        .into_iter()
        .filter(|s| s.definition().monitored)
        .collect()
}

pub fn controllable_services() -> Vec<ServiceName> {
    ALL_SERVICES
        .into_iter()
        .filter(|s| s.definition().controllable)
        .collect()
}

pub fn group_by_category(services: &[ServiceName]) -> Vec<(ServiceCategory, Vec<ServiceName>)> {
    ServiceCategory::ORDER
        .into_iter()
        .map(|category| {
            let in_category = services
                .iter()
                .copied()
                .filter(|s| s.definition().category == category)
                .collect::<Vec<_>>();
            (category, in_category)
        })
        .filter(|(_, services)| !services.is_empty())
        .collect()
}

pub fn to_discord_choices(services: &[ServiceName]) -> Vec<(String, String)> {
    services
        .iter()
        .map(|&name| {
            let def = name.definition();
            (
                format!("{}  {}", def.emoji, def.label),
                name.as_str().to_string(),
            )
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips_every_service_through_its_string_identifier() {
        for service in ALL_SERVICES {
            assert_eq!(ServiceName::from_str(service.as_str()), Some(service));
        }
    }

    #[test]
    fn unknown_identifier_is_rejected() {
        assert_eq!(ServiceName::from_str("not-a-service"), None);
    }

    #[test]
    fn monitored_services_excludes_nothing_today() {
        assert_eq!(monitored_services().len(), ALL_SERVICES.len());
    }
}
