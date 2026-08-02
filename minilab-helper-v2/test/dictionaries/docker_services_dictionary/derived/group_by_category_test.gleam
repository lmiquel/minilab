import dictionaries/docker_services_dictionary/derived/group_by_category.{
  group_by_category,
}
import dictionaries/docker_services_dictionary/types/service_name.{
  Cloudflared, Cobblemon, Mariadb, Valheim, Wireguard,
}
import dictionaries/service_categories_dictionary/types/service_category.{
  Game, Network, Utils,
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
