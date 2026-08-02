import dictionaries/docker_services_dictionary/docker_services_dictionary
import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName,
}
import discord_gleam/ws/packets/interaction_create.{
  type InteractionCreatePacketData, ApplicationCommand, InteractionOption,
  StringValue,
}
import gleam/list
import gleam/option.{Some}

/// Extrait et résout l'option requise `service` d'une interaction de
/// commande slash. Erreur possible seulement en cas d'usage direct de l'API
/// Discord contournant les `choices` du client officiel.
pub fn get_service_option(
  pkt: InteractionCreatePacketData,
) -> Result(ServiceName, Nil) {
  case pkt.data {
    ApplicationCommand(options: Some(options), ..) ->
      case list.find(options, fn(opt) { opt.name == "service" }) {
        Ok(InteractionOption(value: StringValue(raw), ..)) ->
          docker_services_dictionary.service_name_from_string(raw)
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}
