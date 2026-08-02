import dictionaries/docker_services_dictionary/derived/monitored_services
import discord_gleam/types/embed
import gleam/float
import gleam/int
import gleam/option.{Some}
import managers/commands_manager/internals/helpers/add_grouped_service_fields
import managers/commands_manager/internals/helpers/temp_emoji
import managers/docker_manager/docker_manager

const color_green = 0x57F287

/// Port de build-resources-embed.ts. À la différence de /status, une panne
/// sur un service n'est jamais fatale : elle affiche juste
/// "❌ Stats indisponibles" pour ce service.
pub fn build_resources_embed(client: docker_manager.Client) -> embed.Embed {
  let description = case docker_manager.get_rpi_temperature() {
    Ok(temp) ->
      "🌡️ Température RPi : "
      <> temp_emoji.temp_emoji(temp)
      <> " **"
      <> int.to_string(temp)
      <> "°C**"
    Error(_) -> "🌡️ Température RPi : ❌ indisponible"
  }

  let base =
    embed.new(
      title: "📈 Ressources CPU / RAM — minilab",
      description: description,
      color: color_green,
    )

  add_grouped_service_fields.add_grouped_service_fields(
    base,
    monitored_services.monitored_services(),
    fn(service) {
      let value = case docker_manager.get_resource_usage(client, service) {
        Ok(usage) ->
          "CPU : `"
          <> float.to_string(usage.cpu_percent)
          <> "%`\nRAM : `"
          <> int.to_string(usage.mem_usage_mb)
          <> "MB ("
          <> float.to_string(usage.mem_percent)
          <> "%)`"
        Error(_) -> "❌ Stats indisponibles\n(conteneur arrêté ?)"
      }
      Some(value)
    },
  )
}
