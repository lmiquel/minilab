import discord_gleam/types/interaction
import discord_gleam/types/message
import discord_gleam/ws/packets/interaction_create.{
  type InteractionCreatePacketData,
}

pub fn reject_unauthorized(pkt: InteractionCreatePacketData) -> Nil {
  let _ =
    interaction.send_message(
      pkt,
      message: message.new("🚫 Tu n'es pas autorisé à utiliser cette commande."),
      ephemeral: True,
    )
  Nil
}
