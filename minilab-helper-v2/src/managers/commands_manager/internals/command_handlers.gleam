import discord_gleam/bot
import discord_gleam/discord/snowflake.{type Snowflake}
import discord_gleam/ws/packets/interaction_create.{
  type InteractionCreatePacketData,
}
import managers/commands_manager/internals/handlers/handle_resources
import managers/commands_manager/internals/handlers/handle_restart
import managers/commands_manager/internals/handlers/handle_shutdown
import managers/commands_manager/internals/handlers/handle_start
import managers/commands_manager/internals/handlers/handle_status
import managers/commands_manager/internals/handlers/handle_stop
import managers/docker_manager/docker_manager

/// Table de dispatch par nom de commande. VPN et MiniPrint s'ajouteront ici
/// au fil des prochains incréments.
pub fn dispatch(
  client: docker_manager.Client,
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
  name: String,
  pkt: InteractionCreatePacketData,
) -> Nil {
  case name {
    "status" -> handle_status.handle_status(client, pkt)
    "resources" -> handle_resources.handle_resources(client, pkt)
    "start" -> handle_start.handle_start(client, bot, owner_id, pkt)
    "stop" -> handle_stop.handle_stop(client, bot, owner_id, pkt)
    "restart" -> handle_restart.handle_restart(client, bot, owner_id, pkt)
    "shutdown" -> handle_shutdown.handle_shutdown(client, bot, owner_id, pkt)
    _ -> Nil
  }
}
