import gleam/list
import minilab_helper/dictionaries/service_categories.{
  type ServiceCategory, Apps, Game, Network, Utils,
}

// ── Types ────────────────────────────────────────────────────────────────

pub type ServiceName {
  Valheim
  Cobblemon
  Terraria
  PingvinShare
  RollerDerbyScoreboard
  Gitea
  MinilabHelper
  DockerSocketProxy
  GithubRunner
  Mariadb
  Wireguard
  Pihole
  Cloudflared
  Duckdns
}

pub type ServiceDefinition {
  ServiceDefinition(
    container_name: String,
    label: String,
    emoji: String,
    category: ServiceCategory,
    controllable: Bool,
    monitored: Bool,
  )
}

// ── Registre ─────────────────────────────────────────────────────────────

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

// ── Dérivés ──────────────────────────────────────────────────────────────

pub fn all_services() -> List(ServiceName) {
  services()
  |> list.map(fn(pair) { pair.0 })
}

pub fn monitored_services() -> List(ServiceName) {
  services()
  |> list.filter(fn(pair) { pair.1.monitored })
  |> list.map(fn(pair) { pair.0 })
}

pub fn controllable_services() -> List(ServiceName) {
  services()
  |> list.filter(fn(pair) { pair.1.controllable })
  |> list.map(fn(pair) { pair.0 })
}

pub fn group_by_category(
  services: List(ServiceName),
) -> List(#(ServiceCategory, List(ServiceName))) {
  service_categories.category_order()
  |> list.map(fn(category) {
    #(
      category,
      list.filter(services, fn(service) {
        get_service(service).category == category
      }),
    )
  })
  |> list.filter(fn(pair) { pair.1 != [] })
}

pub fn to_discord_choices(
  services: List(ServiceName),
) -> List(#(String, String)) {
  list.map(services, fn(name) {
    let definition = get_service(name)
    #(
      definition.emoji <> "  " <> definition.label,
      service_name_to_string(name),
    )
  })
}
