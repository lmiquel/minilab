import dictionaries/command_dictionary/command_dictionary
import discord_gleam/types/slash_command.{type SlashCommand}
import gleam/list

pub fn build_slash_commands() -> List(SlashCommand) {
  command_dictionary.command_definitions()
  |> list.map(fn(pair) { pair.1 })
}
