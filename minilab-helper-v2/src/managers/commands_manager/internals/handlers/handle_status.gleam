import discord_gleam/types/interaction
import discord_gleam/types/message
import discord_gleam/ws/packets/interaction_create.{
  type InteractionCreatePacketData,
}
import managers/commands_manager/internals/handlers/embed_views/build_status_embed
import managers/docker_manager/docker_manager

pub fn handle_status(
  client: docker_manager.Client,
  pkt: InteractionCreatePacketData,
) -> Nil {
  let _ = interaction.defer_response(pkt, ephemeral: True)

  let reply = case build_status_embed.build_status_embed(client) {
    Ok(embed) -> message.new("") |> message.add_embed(embed)
    Error(_) ->
      message.new(
        "❌ Une erreur est survenue lors de l'exécution de la commande.",
      )
  }

  let _ = interaction.edit_response(pkt, message: reply)
  Nil
}
