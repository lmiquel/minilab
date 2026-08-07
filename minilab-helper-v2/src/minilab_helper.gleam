import booklet
import discord_gleam
import discord_gleam/bot
import discord_gleam/discord/snowflake
import discord_gleam/event_handler.{
  type Packet, InteractionCreatePacket, ReadyPacket,
}
import envoy
import gleam/erlang/process
import gleam/list
import gleam/otp/static_supervisor.{OneForOne}
import gleam/otp/supervision
import gleam/string
import logging
import minilab_helper/backup_report
import minilab_helper/commands
import minilab_helper/docker
import minilab_helper/monitoring
import minilab_helper/wireguard

pub fn main() -> Nil {
  logging.configure()

  let token = require_env("DISCORD_TOKEN")
  let client_id = require_env("DISCORD_CLIENT_ID")
  let owner_id = snowflake.from_string(require_env("DISCORD_OWNER_ID"))
  let wg_peers =
    require_env("WG_PEERS")
    |> string.split(",")
    |> list.map(string.trim)
    |> list.filter(fn(peer) { peer != "" })

  let bot = bot.new(token, client_id)
  let docker = docker.new_client()
  let wireguard_state = wireguard.new_state()
  let has_booted = booklet.new(False)

  let handle_packet = fn(bot: bot.Bot, packet: Packet) {
    case packet {
      ReadyPacket(_) ->
        case booklet.get(has_booted) {
          True -> Nil
          False -> {
            booklet.set(has_booted, True)

            process.spawn_unlinked(fn() {
              commands.register_commands(bot)

              case wg_peers {
                [] -> Nil
                peers ->
                  wireguard.load_peer_names(docker, wireguard_state, peers)
              }

              monitoring.dm(
                bot,
                owner_id,
                "✅ **minilab-helper v2 démarré !**\n"
                  <> "Commandes disponibles : `/status` `/resources` `/start` `/stop` `/restart` `/shutdown` `/vpn` `/miniprint` `/overview`",
              )
            })
            Nil
          }
        }

      InteractionCreatePacket(pkt) -> {
        process.spawn_unlinked(fn() {
          commands.handle_interaction(
            docker,
            bot,
            owner_id,
            wireguard_state,
            pkt,
          )
        })
        Nil
      }

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
      supervision.worker(fn() { monitoring.start(bot, owner_id, docker) }),
    )
    |> static_supervisor.add(
      supervision.worker(fn() {
        wireguard.start(docker, wireguard_state, bot, owner_id)
      }),
    )
    |> static_supervisor.add(
      supervision.worker(fn() { backup_report.start(bot, owner_id) }),
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
