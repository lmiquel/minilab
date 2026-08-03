import discord_gleam/discord/snowflake.{type Snowflake}
import discord_gleam/types/embed.{type Embed}
import discord_gleam/types/interaction
import discord_gleam/types/message
import discord_gleam/ws/packets/interaction_create.{
  type InteractionCreatePacketData, ApplicationCommand, InteractionOption,
  StringValue,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import minilab_helper/common.{type ContainerStatus}
import minilab_helper/dictionaries/docker_services.{type ServiceName}
import minilab_helper/dictionaries/service_categories
import minilab_helper/miniprint/types as miniprint_types

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

/// Même seuils que `temp_emoji`, pour une température en virgule flottante
/// (celle renvoyée par Moonraker) — les deux existent séparément puisque
/// Gleam n'a pas de nombre unique int/float comme TypeScript.
pub fn temp_emoji_float(celsius: Float) -> String {
  case celsius >=. 70.0 {
    True -> "🔴"
    False ->
      case celsius >=. 60.0 {
        True -> "🟡"
        False -> "🟢"
      }
  }
}

pub fn klippy_state_emoji(
  state: Option(miniprint_types.KlippyState),
) -> String {
  case state {
    Some(miniprint_types.Ready) -> "🟢"
    Some(miniprint_types.Startup) -> "🟡"
    Some(miniprint_types.Shutdown) -> "🔴"
    Some(miniprint_types.Error) -> "🔴"
    None -> "⚫"
  }
}

/// Port de format-uptime.ts.
pub fn format_uptime(total_seconds: Int) -> String {
  let days = total_seconds / 86_400
  let hours = total_seconds % 86_400 / 3600
  let minutes = total_seconds % 3600 / 60

  case days > 0 {
    True -> int.to_string(days) <> "j " <> int.to_string(hours) <> "h"
    False ->
      case hours > 0 {
        True -> int.to_string(hours) <> "h " <> int.to_string(minutes) <> "min"
        False -> int.to_string(minutes) <> "min"
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
