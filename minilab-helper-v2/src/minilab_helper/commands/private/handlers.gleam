import booklet
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
import gleam/option
import minilab_helper/commands/private
import minilab_helper/commands/private/embed_views
import minilab_helper/dictionaries/docker_services.{all_services, get_service}
import minilab_helper/dictionaries/service_categories.{Network}
import minilab_helper/docker/public as docker
import minilab_helper/miniprint/public as miniprint
import minilab_helper/monitoring/public as monitoring
import minilab_helper/wireguard/public as wireguard
import minilab_helper/wireguard/types.{type WireGuardState}

// ── /status ──────────────────────────────────────────────────────────────

pub fn handle_status(
  client: docker.Client,
  pkt: InteractionCreatePacketData,
) -> Nil {
  let _ = interaction.defer_response(pkt, ephemeral: True)

  let reply = case embed_views.build_status_embed(client) {
    Ok(embed) -> message.new("") |> message.add_embed(embed)
    Error(_) ->
      message.new(
        "❌ Une erreur est survenue lors de l'exécution de la commande.",
      )
  }

  let _ = interaction.edit_response(pkt, message: reply)
  Nil
}

// ── /resources ───────────────────────────────────────────────────────────

pub fn handle_resources(
  client: docker.Client,
  pkt: InteractionCreatePacketData,
) -> Nil {
  let _ = interaction.defer_response(pkt, ephemeral: True)

  let embed = embed_views.build_resources_embed(client)
  let reply = message.new("") |> message.add_embed(embed)

  let _ = interaction.edit_response(pkt, message: reply)
  Nil
}

// ── /vpn ─────────────────────────────────────────────────────────────────

pub fn handle_vpn(
  wireguard_state: booklet.Booklet(WireGuardState),
  pkt: InteractionCreatePacketData,
) -> Nil {
  let _ = interaction.defer_response(pkt, ephemeral: True)

  let embed =
    wireguard.get_connected_peers(wireguard_state)
    |> embed_views.build_vpn_embed()

  let _ =
    interaction.edit_response(
      pkt,
      message: message.new("") |> message.add_embed(embed),
    )
  Nil
}

// ── /miniprint ───────────────────────────────────────────────────────────

const miniprint_peer_name = "MiniPrint"

pub fn handle_miniprint(
  wireguard_state: booklet.Booklet(WireGuardState),
  pkt: InteractionCreatePacketData,
) -> Nil {
  let _ = interaction.defer_response(pkt, ephemeral: True)

  let overview = miniprint.get_overview()
  let peer =
    wireguard.get_all_peers(wireguard_state)
    |> list.find(fn(p) { p.name == miniprint_peer_name })
    |> option.from_result

  let embed = embed_views.build_miniprint_embed(overview, peer)

  let _ =
    interaction.edit_response(
      pkt,
      message: message.new("") |> message.add_embed(embed),
    )
  Nil
}

// ── /overview ────────────────────────────────────────────────────────────

pub fn handle_overview(
  client: docker.Client,
  wireguard_state: booklet.Booklet(WireGuardState),
  pkt: InteractionCreatePacketData,
) -> Nil {
  let _ = interaction.defer_response(pkt, ephemeral: True)

  let status_subj = process.new_subject()
  process.spawn_unlinked(fn() {
    process.send(
      status_subj,
      embed_views.build_overview_status_resources_embed(client),
    )
  })

  let miniprint_subj = process.new_subject()
  process.spawn_unlinked(fn() {
    let overview = miniprint.get_overview()
    let peer =
      wireguard.get_all_peers(wireguard_state)
      |> list.find(fn(p) { p.name == miniprint_peer_name })
      |> option.from_result
    process.send(
      miniprint_subj,
      embed_views.build_miniprint_embed(overview, peer),
    )
  })

  let vpn_embed =
    wireguard.get_all_peers(wireguard_state)
    |> embed_views.build_overview_vpn_embed()

  let status_result = process.receive(status_subj, within: 6000)
  let miniprint_embed_result = process.receive(miniprint_subj, within: 6000)

  case status_result, miniprint_embed_result {
    Ok(Ok(status_embed)), Ok(miniprint_embed) -> {
      let _ =
        interaction.edit_response(
          pkt,
          message: message.new("")
            |> message.add_embed(status_embed)
            |> message.add_embed(vpn_embed)
            |> message.add_embed(miniprint_embed),
        )
      Nil
    }
    _, _ -> {
      let _ =
        interaction.edit_response(
          pkt,
          message: message.new(
            "❌ Une erreur est survenue lors de l'exécution de la commande.",
          ),
        )
      Nil
    }
  }
}

// ── /start /stop /restart ────────────────────────────────────────────────

pub fn handle_start(
  client: docker.Client,
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
  pkt: InteractionCreatePacketData,
) -> Nil {
  let _ = interaction.defer_response(pkt, ephemeral: True)

  case private.get_service_option(pkt) {
    Error(Nil) -> {
      let _ =
        interaction.edit_response(
          pkt,
          message: message.new("❌ Service inconnu."),
        )
      Nil
    }

    Ok(service) -> {
      let definition = get_service(service)

      case docker.start_service(client, service) {
        Ok(Nil) -> {
          let _ =
            interaction.edit_response(
              pkt,
              message: message.new(
                definition.emoji
                <> " **"
                <> definition.label
                <> "** démarré avec succès.",
              ),
            )
          monitoring.dm(
            bot,
            owner_id,
            "▶️ **"
              <> definition.label
              <> "** a été démarré manuellement via Discord.",
          )
        }

        Error(_) -> {
          let _ =
            interaction.edit_response(
              pkt,
              message: message.new(
                "❌ Une erreur est survenue lors de l'exécution de la commande.",
              ),
            )
          Nil
        }
      }
    }
  }
}

pub fn handle_stop(
  client: docker.Client,
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
  pkt: InteractionCreatePacketData,
) -> Nil {
  let _ = interaction.defer_response(pkt, ephemeral: True)

  case private.get_service_option(pkt) {
    Error(Nil) -> {
      let _ =
        interaction.edit_response(
          pkt,
          message: message.new("❌ Service inconnu."),
        )
      Nil
    }

    Ok(service) -> {
      let definition = get_service(service)

      case definition.category {
        Network -> {
          let _ =
            interaction.send_followup(
              pkt,
              message: message.new(
                "⚠️ Arrêter **"
                <> definition.label
                <> "** peut impacter les autres services.",
              )
                |> message.set_ephemeral(True),
            )
          Nil
        }
        _ -> Nil
      }

      case docker.stop_service(client, service) {
        Ok(Nil) -> {
          let _ =
            interaction.edit_response(
              pkt,
              message: message.new(
                definition.emoji
                <> " **"
                <> definition.label
                <> "** arrêté avec succès.",
              ),
            )
          monitoring.dm(
            bot,
            owner_id,
            "🛑 **"
              <> definition.label
              <> "** a été arrêté manuellement via Discord.",
          )
        }

        Error(_) -> {
          let _ =
            interaction.edit_response(
              pkt,
              message: message.new(
                "❌ Une erreur est survenue lors de l'exécution de la commande.",
              ),
            )
          Nil
        }
      }
    }
  }
}

pub fn handle_restart(
  client: docker.Client,
  bot: bot.Bot,
  owner_id: Snowflake(snowflake.User),
  pkt: InteractionCreatePacketData,
) -> Nil {
  let _ = interaction.defer_response(pkt, ephemeral: True)

  case private.get_service_option(pkt) {
    Error(Nil) -> {
      let _ =
        interaction.edit_response(
          pkt,
          message: message.new("❌ Service inconnu."),
        )
      Nil
    }

    Ok(service) -> {
      let definition = get_service(service)

      case docker.restart_service(client, service) {
        Ok(Nil) -> {
          let _ =
            interaction.edit_response(
              pkt,
              message: message.new(
                definition.emoji
                <> " **"
                <> definition.label
                <> "** redémarré avec succès.",
              ),
            )
          monitoring.dm(
            bot,
            owner_id,
            "🔁 **"
              <> definition.label
              <> "** a été redémarré manuellement via Discord.",
          )
        }

        Error(_) -> {
          let _ =
            interaction.edit_response(
              pkt,
              message: message.new(
                "❌ Une erreur est survenue lors de l'exécution de la commande.",
              ),
            )
          Nil
        }
      }
    }
  }
}

// ── /shutdown ────────────────────────────────────────────────────────────

pub fn handle_shutdown(
  client: docker.Client,
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

  monitoring.dm(
    bot,
    owner_id,
    "🔴 **SHUTDOWN du Raspberry Pi déclenché via Discord.**\n"
      <> "Arrêt propre de tous les services puis extinction dans 10 secondes.",
  )

  list.each(all_services(), fn(service) {
    let _ = docker.stop_service(client, service)
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
