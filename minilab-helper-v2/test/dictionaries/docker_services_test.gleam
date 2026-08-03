import gleam/list
import minilab_helper/dictionaries/docker_services.{
  Cloudflared, Cobblemon, Gitea, Mariadb, PingvinShare, RollerDerbyScoreboard,
  Terraria, Valheim, Wireguard, all_services, controllable_services,
  group_by_category, service_name_from_string, service_name_to_string,
}
import minilab_helper/dictionaries/service_categories.{Game, Network, Utils}

pub fn service_name_round_trips_for_every_service_test() {
  list.each(all_services(), fn(name) {
    let assert Ok(round_tripped) =
      service_name_to_string(name) |> service_name_from_string()
    assert round_tripped == name
  })
}

pub fn service_name_from_string_rejects_unknown_values_test() {
  assert service_name_from_string("not-a-real-service") == Error(Nil)
}

pub fn only_the_seven_controllable_services_are_returned_test() {
  assert controllable_services()
    == [
      Valheim,
      Cobblemon,
      Terraria,
      PingvinShare,
      RollerDerbyScoreboard,
      Gitea,
      Mariadb,
    ]
}

pub fn groups_follow_the_fixed_category_order_test() {
  // Réseau avant Jeux dans la liste d'entrée, mais Game doit sortir en
  // premier — l'ordre suit CATEGORY_ORDER, pas l'ordre d'entrée.
  let grouped = group_by_category([Cloudflared, Valheim])

  assert grouped == [#(Game, [Valheim]), #(Network, [Cloudflared])]
}

pub fn empty_categories_are_dropped_test() {
  let grouped = group_by_category([Valheim, Cobblemon])

  assert grouped == [#(Game, [Valheim, Cobblemon])]
}

pub fn services_keep_their_relative_order_within_a_category_test() {
  let grouped = group_by_category([Cobblemon, Valheim])

  assert grouped == [#(Game, [Cobblemon, Valheim])]
}

pub fn an_empty_input_produces_no_groups_test() {
  assert group_by_category([]) == []
}

pub fn mixed_categories_are_all_grouped_test() {
  let grouped = group_by_category([Mariadb, Wireguard, Valheim])

  assert grouped
    == [#(Game, [Valheim]), #(Utils, [Mariadb]), #(Network, [Wireguard])]
}
