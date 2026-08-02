import discord_gleam
import discord_gleam/bot
import discord_gleam/discord/snowflake
import discord_gleam/event_handler.{
  type Packet, InteractionCreatePacket, ReadyPacket,
}
import envoy
import gleam/erlang/process
import gleam/otp/static_supervisor.{OneForOne}
import gleam/otp/supervision
import logging
import managers/commands_manager/commands_manager
import managers/docker_manager/docker_manager
import managers/monitoring_manager/monitoring_manager

/// Équivalent de index.ts : vérifie les variables d'environnement requises,
/// construit le bot et le client Docker, câble le superviseur, puis boot.
pub fn main() -> Nil {
  logging.configure()

  let token = require_env("DISCORD_TOKEN")
  let client_id = require_env("DISCORD_CLIENT_ID")
  let owner_id = snowflake.from_string(require_env("DISCORD_OWNER_ID"))

  let bot = bot.new(token, client_id)
  let docker = docker_manager.new_client()

  let handle_packet = fn(bot: bot.Bot, packet: Packet) {
    case packet {
      ReadyPacket(_) -> {
        commands_manager.register_commands(bot)
        monitoring_manager.dm(
          bot,
          owner_id,
          "✅ **minilab-helper v2 démarré !**\n"
            <> "Commandes disponibles : `/status` `/resources`",
        )
      }

      InteractionCreatePacket(pkt) ->
        commands_manager.handle_interaction(docker, bot, owner_id, pkt)

      _ -> Nil
    }
  }

  let assert Ok(_) =
    static_supervisor.new(OneForOne)
    |> static_supervisor.add(
      supervision.worker(fn() {
        discord_gleam.simple(bot, [handle_packet]) |> discord_gleam.start()
      }),
    )
    |> static_supervisor.add(
      supervision.worker(fn() {
        monitoring_manager.start(bot, owner_id, docker)
      }),
    )
    |> static_supervisor.start()

  process.sleep_forever()
}

fn require_env(name: String) -> String {
  case envoy.get(name) {
    Ok(value) -> value
    Error(Nil) ->
      panic as { "[Bot] Variable d'environnement manquante : " <> name }
  }
}
