import dictionaries/command_dictionary/types/command_name.{
  type CommandName, Resources, Restart, Shutdown, Start, Status, Stop,
}
import dictionaries/docker_services_dictionary/derived/controllable_services.{
  controllable_services,
}
import dictionaries/docker_services_dictionary/derived/to_discord_choices.{
  to_discord_choices,
}
import discord_gleam/types/slash_command.{
  type SlashCommand, CommandOption, SlashCommand, StringOption,
}

fn service_option(description: String) -> slash_command.CommandOption {
  CommandOption(
    name: "service",
    description: description,
    type_: StringOption,
    required: True,
    choices: to_discord_choices(controllable_services()),
  )
}

/// Définitions des slash commands. VPN et MiniPrint arriveront ici au fil
/// des prochains incréments.
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
  ]
}
