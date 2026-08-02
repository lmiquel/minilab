import dictionaries/docker_services_dictionary/derived/controllable_services.{
  controllable_services,
}
import dictionaries/docker_services_dictionary/types/service_name.{
  Cobblemon, Gitea, Mariadb, PingvinShare, RollerDerbyScoreboard, Terraria,
  Valheim,
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
