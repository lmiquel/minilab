import dictionaries/command_dictionary/types/command_name.{
  type CommandName, Resources, Status,
}
import discord_gleam/types/slash_command.{type SlashCommand, SlashCommand}

/// Définitions des slash commands du MVP. Les commandes de contrôle,
/// VPN et MiniPrint arriveront ici au fil des prochains incréments.
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
  ]
}
