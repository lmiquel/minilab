import commons/types/container_status.{type ContainerStatus}
import dictionaries/docker_services_dictionary/derived/monitored_services
import discord_gleam/types/embed
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import managers/commands_manager/internals/helpers/add_grouped_service_fields
import managers/commands_manager/internals/helpers/render_container_state_line
import managers/docker_manager/docker_manager
import managers/docker_manager/types/docker_error.{type DockerError}

const color_blurple = 0x5865F2

/// Port de build-status-embed.ts. Comme le v1, échoue entièrement si
/// get_all_statuses échoue (`Promise.all` fail-fast côté v1).
pub fn build_status_embed(
  client: docker_manager.Client,
) -> Result(embed.Embed, DockerError) {
  use statuses <- result.try(docker_manager.get_all_statuses(client))

  let base =
    embed.new(
      title: "📊 Statut du minilab",
      description: "",
      color: color_blurple,
    )

  let with_fields =
    add_grouped_service_fields.add_grouped_service_fields(
      base,
      monitored_services.monitored_services(),
      fn(service) { field_value(statuses, service) },
    )

  Ok(with_fields)
}

fn field_value(statuses: List(ContainerStatus), service) {
  case list.find(statuses, fn(status) { status.name == service }) {
    Error(Nil) -> None
    Ok(status) ->
      Some(
        render_container_state_line.render_container_state_line(status)
        <> "  •  🔁 "
        <> int.to_string(status.restart_count),
      )
  }
}
