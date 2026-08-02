import dictionaries/docker_services_dictionary/docker_services_dictionary
import discord_gleam/bot
import discord_gleam/discord/snowflake.{type Snowflake}
import discord_gleam/types/interaction
import discord_gleam/types/message
import discord_gleam/ws/packets/interaction_create.{
  type InteractionCreatePacketData,
}
import managers/commands_manager/internals/helpers/get_service_option
import managers/docker_manager/docker_manager
import managers/monitoring_manager/monitoring_manager

pub fn handle_start(
  client: docker_manager.Client,
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
  pkt: InteractionCreatePacketData,
) -> Nil {
  let _ = interaction.defer_response(pkt, ephemeral: True)

  case get_service_option.get_service_option(pkt) {
    Error(Nil) -> {
      let _ =
        interaction.edit_response(
          pkt,
          message: message.new("❌ Service inconnu."),
        )
      Nil
    }

    Ok(service) -> {
      let definition = docker_services_dictionary.get_service(service)

      case docker_manager.start_service(client, service) {
        Ok(Nil) -> {
          let _ =
            interaction.edit_response(
              pkt,
              message: message.new(
                definition.emoji
                <> " **"
                <> definition.label
                <> "** démarré avec succès.",
              ),
            )
          monitoring_manager.dm(
            bot,
            owner_id,
            "▶️ **"
              <> definition.label
              <> "** a été démarré manuellement via Discord.",
          )
        }

        Error(_) -> {
          let _ =
            interaction.edit_response(
              pkt,
              message: message.new(
                "❌ Une erreur est survenue lors de l'exécution de la commande.",
              ),
            )
          Nil
        }
      }
    }
  }
}
