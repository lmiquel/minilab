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

/// Identifiants canoniques v1 (clés du dictionnaire `SERVICES`), pas les
/// noms de conteneur — diffèrent pour pingvinshare, minilabhelper,
/// dockersocketproxy et githubrunner.
pub fn service_name_to_string(name: ServiceName) -> String {
  case name {
    Valheim -> "valheim"
    Cobblemon -> "cobblemon"
    Terraria -> "terraria"
    PingvinShare -> "pingvinshare"
    RollerDerbyScoreboard -> "rollerderbyscoreboard"
    Gitea -> "gitea"
    MinilabHelper -> "minilabhelper"
    DockerSocketProxy -> "dockersocketproxy"
    GithubRunner -> "githubrunner"
    Mariadb -> "mariadb"
    Wireguard -> "wireguard"
    Pihole -> "pihole"
    Cloudflared -> "cloudflared"
    Duckdns -> "duckdns"
  }
}

pub fn service_name_from_string(value: String) -> Result(ServiceName, Nil) {
  case value {
    "valheim" -> Ok(Valheim)
    "cobblemon" -> Ok(Cobblemon)
    "terraria" -> Ok(Terraria)
    "pingvinshare" -> Ok(PingvinShare)
    "rollerderbyscoreboard" -> Ok(RollerDerbyScoreboard)
    "gitea" -> Ok(Gitea)
    "minilabhelper" -> Ok(MinilabHelper)
    "dockersocketproxy" -> Ok(DockerSocketProxy)
    "githubrunner" -> Ok(GithubRunner)
    "mariadb" -> Ok(Mariadb)
    "wireguard" -> Ok(Wireguard)
    "pihole" -> Ok(Pihole)
    "cloudflared" -> Ok(Cloudflared)
    "duckdns" -> Ok(Duckdns)
    _ -> Error(Nil)
  }
}
