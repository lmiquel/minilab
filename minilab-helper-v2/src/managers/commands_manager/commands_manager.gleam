import dictionaries/command_dictionary/derived/build_slash_commands
import discord_gleam
import discord_gleam/bot
import discord_gleam/discord/snowflake.{type Snowflake}
import discord_gleam/ws/packets/interaction_create.{
  type InteractionCreatePacketData, ApplicationCommand,
}
import gleam/string
import logging
import managers/commands_manager/internals/command_handlers
import managers/commands_manager/internals/helpers/is_owner
import managers/commands_manager/internals/helpers/reject_unauthorized
import managers/docker_manager/docker_manager

/// Enregistre les slash commands globalement. Équivalent de
/// commands-manager.ts's registerCommands.
pub fn register_commands(bot: bot.Bot) -> Nil {
  case
    discord_gleam.register_global_commands(
      bot,
      build_slash_commands.build_slash_commands(),
    )
  {
    Ok(_) ->
      logging.log(
        logging.Info,
        "[Commands] Commandes slash enregistrées globalement.",
      )
    Error(#(command, err)) ->
      logging.log(
        logging.Error,
        "[Commands] Erreur enregistrement "
          <> command.name
          <> ": "
          <> string.inspect(err),
      )
  }
}

/// Gère une interaction entrante : gate owner, puis dispatch par nom de
/// commande. Équivalent du listener installé par setupCommandHandler.
pub fn handle_interaction(
  client: docker_manager.Client,
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
  pkt: InteractionCreatePacketData,
) -> Nil {
  case is_owner.is_owner(pkt, owner_id) {
    False -> reject_unauthorized.reject_unauthorized(pkt)
    True ->
      case pkt.data {
        ApplicationCommand(name: name, ..) ->
          command_handlers.dispatch(client, bot, owner_id, name, pkt)
        _ -> Nil
      }
  }
}
