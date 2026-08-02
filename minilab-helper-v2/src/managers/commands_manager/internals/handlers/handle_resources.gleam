import discord_gleam/types/interaction
import discord_gleam/types/message
import discord_gleam/ws/packets/interaction_create.{
  type InteractionCreatePacketData,
}
import managers/commands_manager/internals/handlers/embed_views/build_resources_embed
import managers/docker_manager/docker_manager

pub fn handle_resources(
  client: docker_manager.Client,
  pkt: InteractionCreatePacketData,
) -> Nil {
  let _ = interaction.defer_response(pkt, ephemeral: True)

  let embed = build_resources_embed.build_resources_embed(client)
  let reply = message.new("") |> message.add_embed(embed)

  let _ = interaction.edit_response(pkt, message: reply)
  Nil
}
