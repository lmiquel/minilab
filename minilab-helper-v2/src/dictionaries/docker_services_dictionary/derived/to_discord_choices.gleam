import dictionaries/docker_services_dictionary/docker_services_dictionary
import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName,
}
import gleam/list

/// `#(name, value)` pour alimenter les `choices` d'une option de commande
/// slash — `value` est l'identifiant canonique (voir `service_name_to_string`).
pub fn to_discord_choices(
  services: List(ServiceName),
) -> List(#(String, String)) {
  list.map(services, fn(name) {
    let definition = docker_services_dictionary.get_service(name)
    #(
      definition.emoji <> "  " <> definition.label,
      docker_services_dictionary.service_name_to_string(name),
    )
  })
}
