import discord_gleam/discord/snowflake.{type Snowflake}
import discord_gleam/types/embed.{type Embed}
import discord_gleam/types/interaction
import discord_gleam/types/message
import discord_gleam/ws/packets/interaction_create.{
  type InteractionCreatePacketData, ApplicationCommand, InteractionOption,
  StringValue,
}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import minilab_helper/common.{type ContainerStatus}
import minilab_helper/dictionaries/docker_services.{type ServiceName}
import minilab_helper/dictionaries/service_categories

// ── Autorisation ─────────────────────────────────────────────────────────

pub fn is_owner(
  pkt: InteractionCreatePacketData,
  owner_id: Snowflake(snowflake.User),
) -> Bool {
  case pkt.user, pkt.member {
    Some(user), _ -> snowflake.compare(user.id, owner_id) == order.Eq
    None, Some(member) ->
      snowflake.compare(member.user.id, owner_id) == order.Eq
    None, None -> False
  }
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

// ── Options de commande ──────────────────────────────────────────────────

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
          docker_services.service_name_from_string(raw)
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

// ── Rendu ────────────────────────────────────────────────────────────────

pub fn temp_emoji(celsius: Int) -> String {
  case celsius >= 70 {
    True -> "🔴"
    False ->
      case celsius >= 60 {
        True -> "🟡"
        False -> "🟢"
      }
  }
}

/// Si healthcheck dispo → on affiche uniquement son résultat (running
/// implicite). Sinon → on affiche l'état Docker.
pub fn render_container_state_line(status: ContainerStatus) -> String {
  let is_running = status.state == "running"
  let has_health = status.health != common.NoHealthcheck

  case has_health && is_running {
    True ->
      common.health_emoji(status.health)
      <> " `"
      <> common.health_status_to_string(status.health)
      <> "`"

    False -> {
      let dot = case is_running {
        True -> "🟢"
        False -> "🔴"
      }
      dot <> " `" <> status.state <> "`"
    }
  }
}

/// Ajoute un champ d'en-tête par catégorie (ordre Game/Apps/Utils/Network)
/// suivi d'un champ par service dans cette catégorie. `build_value` renvoie
/// `None` pour omettre un service (ex : statut indisponible).
pub fn add_grouped_service_fields(
  embed: Embed,
  services: List(ServiceName),
  build_value: fn(ServiceName) -> Option(String),
) -> Embed {
  docker_services.group_by_category(services)
  |> list.fold(embed, fn(embed, pair) {
    let #(category, services_in_category) = pair

    let embed =
      embed.add_field(
        embed,
        name: "​",
        value: "**" <> service_categories.category_label(category) <> "**",
        inline: False,
      )

    list.fold(services_in_category, embed, fn(embed, service) {
      case build_value(service) {
        None -> embed
        Some(value) -> {
          let definition = docker_services.get_service(service)
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
