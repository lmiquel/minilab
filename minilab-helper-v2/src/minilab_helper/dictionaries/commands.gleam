import discord_gleam/types/slash_command.{
  type SlashCommand, CommandOption, SlashCommand, StringOption,
}
import gleam/list
import minilab_helper/dictionaries/docker_services

// ── Types ────────────────────────────────────────────────────────────────

pub type CommandName {
  Status
  Resources
  Start
  Stop
  Restart
  Shutdown
  Vpn
}

// ── Définitions ──────────────────────────────────────────────────────────

fn service_option(description: String) -> slash_command.CommandOption {
  CommandOption(
    name: "service",
    description: description,
    type_: StringOption,
    required: True,
    choices: docker_services.to_discord_choices(
      docker_services.controllable_services(),
    ),
  )
}

/// Définitions des slash commands. MiniPrint arrivera ici au fil du
/// prochain incrément.
pub fn command_definitions() -> List(#(CommandName, SlashCommand)) {
  [
    #(
      Status,
      SlashCommand(
        name: "status",
        description: "Affiche le statut de tous les services minilab",
        options: [],
      ),
    ),
    #(
      Resources,
      SlashCommand(
        name: "resources",
        description: "Affiche la consommation CPU/RAM et la température du RPi",
        options: [],
      ),
    ),
    #(
      Start,
      SlashCommand(name: "start", description: "Démarre un service", options: [
        service_option("Le service à démarrer"),
      ]),
    ),
    #(
      Stop,
      SlashCommand(name: "stop", description: "Arrête un service", options: [
        service_option("Le service à arrêter"),
      ]),
    ),
    #(
      Restart,
      SlashCommand(
        name: "restart",
        description: "Redémarre un service",
        options: [service_option("Le service à redémarrer")],
      ),
    ),
    #(
      Shutdown,
      SlashCommand(
        name: "shutdown",
        description: "⚠️  Éteint complètement le Raspberry Pi (arrête tous les services d'abord)",
        options: [],
      ),
    ),
    #(
      Vpn,
      SlashCommand(
        name: "vpn",
        description: "Affiche les peers WireGuard actuellement connectés",
        options: [],
      ),
    ),
  ]
}

// ── Dérivés ──────────────────────────────────────────────────────────────

pub fn build_slash_commands() -> List(SlashCommand) {
  command_definitions()
  |> list.map(fn(pair) { pair.1 })
}
