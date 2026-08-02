import discord_gleam/ws/packets/interaction_create.{
  type InteractionCreatePacketData,
}
import managers/commands_manager/internals/handlers/handle_resources
import managers/commands_manager/internals/handlers/handle_status
import managers/docker_manager/docker_manager

/// Table de dispatch par nom de commande. Les commandes de contrôle, VPN et
/// MiniPrint s'ajouteront ici au fil des prochains incréments.
pub fn dispatch(
  client: docker_manager.Client,
  name: String,
  pkt: InteractionCreatePacketData,
) -> Nil {
  case name {
    "status" -> handle_status.handle_status(client, pkt)
    "resources" -> handle_resources.handle_resources(client, pkt)
    _ -> Nil
  }
}
