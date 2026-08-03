import booklet
import discord_gleam
import discord_gleam/bot
import discord_gleam/discord/snowflake.{type Snowflake}
import discord_gleam/ws/packets/interaction_create.{
  type InteractionCreatePacketData, ApplicationCommand,
}
import gleam/string
import logging
import minilab_helper/commands/private
import minilab_helper/commands/private/handlers
import minilab_helper/dictionaries/commands.{build_slash_commands}
import minilab_helper/docker/public as docker
import minilab_helper/wireguard/types.{type WireGuardState}

/// Enregistre les slash commands globalement. Équivalent de
/// commands-manager.ts's registerCommands.
pub fn register_commands(bot: bot.Bot) -> Nil {
  case
    discord_gleam.bulk_overwrite_global_commands(bot, build_slash_commands())
  {
    Ok(_) ->
      logging.log(
        logging.Info,
        "[Commands] Commandes slash enregistrées globalement.",
      )
    Error(err) ->
      logging.log(
        logging.Error,
        "[Commands] Erreur enregistrement commandes: " <> string.inspect(err),
      )
  }
}

/// Gère une interaction entrante : gate owner, puis dispatch par nom de
/// commande. Équivalent du listener installé par setupCommandHandler.
pub fn handle_interaction(
  client: docker.Client,
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
  wireguard_state: booklet.Booklet(WireGuardState),
  pkt: InteractionCreatePacketData,
) -> Nil {
  case private.is_owner(pkt, owner_id) {
    False -> private.reject_unauthorized(pkt)
    True ->
      case pkt.data {
        ApplicationCommand(name: name, ..) ->
          dispatch(client, bot, owner_id, wireguard_state, name, pkt)
        _ -> Nil
      }
  }
}

/// Table de dispatch par nom de commande. MiniPrint s'ajoutera ici au fil
/// du prochain incrément.
fn dispatch(
  client: docker.Client,
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
  wireguard_state: booklet.Booklet(WireGuardState),
  name: String,
  pkt: InteractionCreatePacketData,
) -> Nil {
  case name {
    "status" -> handlers.handle_status(client, pkt)
    "resources" -> handlers.handle_resources(client, pkt)
    "start" -> handlers.handle_start(client, bot, owner_id, pkt)
    "stop" -> handlers.handle_stop(client, bot, owner_id, pkt)
    "restart" -> handlers.handle_restart(client, bot, owner_id, pkt)
    "shutdown" -> handlers.handle_shutdown(client, bot, owner_id, pkt)
    "vpn" -> handlers.handle_vpn(wireguard_state, pkt)
    "miniprint" -> handlers.handle_miniprint(wireguard_state, pkt)
    "overview" -> handlers.handle_overview(client, wireguard_state, pkt)
    _ -> Nil
  }
}
