import dictionaries/docker_services_dictionary/derived/all_services
import discord_gleam/bot
import discord_gleam/discord/snowflake.{type Snowflake}
import discord_gleam/types/interaction
import discord_gleam/types/message
import discord_gleam/ws/packets/interaction_create.{
  type InteractionCreatePacketData,
}
import gleam/erlang/charlist
import gleam/erlang/process
import gleam/list
import managers/docker_manager/docker_manager
import managers/monitoring_manager/monitoring_manager

pub fn handle_shutdown(
  client: docker_manager.Client,
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
  pkt: InteractionCreatePacketData,
) -> Nil {
  let _ = interaction.defer_response(pkt, ephemeral: True)

  let _ =
    interaction.edit_response(
      pkt,
      message: message.new(
        "⚠️ **Extinction du Raspberry Pi dans 10 secondes…**\n"
        <> "Tous les services sont arrêtés proprement avant l'extinction.",
      ),
    )

  monitoring_manager.dm(
    bot,
    owner_id,
    "🔴 **SHUTDOWN du Raspberry Pi déclenché via Discord.**\n"
      <> "Arrêt propre de tous les services puis extinction dans 10 secondes.",
  )

  list.each(all_services.all_services(), fn(service) {
    let _ = docker_manager.stop_service(client, service)
    Nil
  })

  process.spawn_unlinked(fn() {
    process.sleep(10_000)
    os_cmd(charlist.from_string("sudo shutdown -h now"))
    Nil
  })

  Nil
}

@external(erlang, "os", "cmd")
fn os_cmd(command: charlist.Charlist) -> charlist.Charlist
