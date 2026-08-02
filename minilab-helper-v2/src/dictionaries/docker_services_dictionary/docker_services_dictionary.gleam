import dictionaries/docker_services_dictionary/types/service_definition.{
  type ServiceDefinition, ServiceDefinition,
}
import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName, Cloudflared, Cobblemon, DockerSocketProxy, Duckdns, Gitea,
  GithubRunner, Mariadb, MinilabHelper, Pihole, PingvinShare,
  RollerDerbyScoreboard, Terraria, Valheim, Wireguard,
}
import dictionaries/service_categories_dictionary/types/service_category.{
  Apps, Game, Network, Utils,
}
import gleam/list

pub fn services() -> List(#(ServiceName, ServiceDefinition)) {
  [
    #(Valheim, ServiceDefinition("valheim", "Valheim", "🌲", Game, True, True)),
    #(
      Cobblemon,
      ServiceDefinition("cobblemon", "Cobblemon", "🎊", Game, True, True),
    ),
    #(
      Terraria,
      ServiceDefinition("terraria", "Terraria", "⛏️", Game, True, True),
    ),
    #(
      PingvinShare,
      ServiceDefinition("pingvin-share", "Pingvin Share", "🐧", Apps, True, True),
    ),
    #(
      RollerDerbyScoreboard,
      ServiceDefinition(
        "rollerderbyscoreboard",
        "Roller Derby Scoreboard (Carolina)",
        "🛼",
        Apps,
        True,
        True,
      ),
    ),
    #(Gitea, ServiceDefinition("gitea", "Gitea", "🍵", Apps, True, True)),
    #(
      MinilabHelper,
      ServiceDefinition(
        "minilab-helper-v2",
        "Minilab Helper",
        "🤖",
        Apps,
        False,
        True,
      ),
    ),
    #(
      DockerSocketProxy,
      ServiceDefinition(
        "docker-socket-proxy",
        "Docker Socket Proxy",
        "🔌",
        Utils,
        False,
        True,
      ),
    ),
    #(
      GithubRunner,
      ServiceDefinition(
        "github-runner",
        "GitHub Runner",
        "🐙",
        Utils,
        False,
        True,
      ),
    ),
    #(Mariadb, ServiceDefinition("mariadb", "MariaDB", "🦭", Utils, True, True)),
    #(
      Wireguard,
      ServiceDefinition("wireguard", "WireGuard", "🔒", Network, False, True),
    ),
    #(Pihole, ServiceDefinition("pihole", "Pi-hole", "🕳️", Network, False, True)),
    #(
      Cloudflared,
      ServiceDefinition("cloudflared", "Cloudflared", "☁️", Network, False, True),
    ),
    #(
      Duckdns,
      ServiceDefinition("duckdns", "DuckDNS", "🦆", Network, False, True),
    ),
  ]
}

pub fn get_service(name: ServiceName) -> ServiceDefinition {
  let assert Ok(definition) = list.key_find(services(), name)
  definition
}
