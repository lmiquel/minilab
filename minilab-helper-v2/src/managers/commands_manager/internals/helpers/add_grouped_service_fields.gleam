import dictionaries/docker_services_dictionary/derived/group_by_category
import dictionaries/docker_services_dictionary/docker_services_dictionary
import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName,
}
import dictionaries/service_categories_dictionary/service_categories_dictionary
import discord_gleam/types/embed.{type Embed}
import gleam/list
import gleam/option.{type Option, None, Some}

/// Ajoute un champ d'en-tête par catégorie (ordre Game/Apps/Utils/Network)
/// suivi d'un champ par service dans cette catégorie. `build_value` renvoie
/// `None` pour omettre un service (ex : statut indisponible).
pub fn add_grouped_service_fields(
  embed: Embed,
  services: List(ServiceName),
  build_value: fn(ServiceName) -> Option(String),
) -> Embed {
  group_by_category.group_by_category(services)
  |> list.fold(embed, fn(embed, pair) {
    let #(category, services_in_category) = pair

    let embed =
      embed.add_field(
        embed,
        name: "​",
        value: "**"
          <> service_categories_dictionary.category_label(category)
          <> "**",
        inline: False,
      )

    list.fold(services_in_category, embed, fn(embed, service) {
      case build_value(service) {
        None -> embed
        Some(value) -> {
          let definition = docker_services_dictionary.get_service(service)
          embed.add_field(
            embed,
            name: definition.emoji <> " " <> definition.label,
            value: value,
            inline: True,
          )
        }
      }
    })
  })
}
