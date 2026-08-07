import minilab_helper/dictionaries/docker_services.{Cloudflared, Valheim}
import minilab_helper/docker.{
  ContainerStatus, Healthy, NoHealthcheck, Starting, Unhealthy,
}
import minilab_helper/monitoring.{ServiceState, check_status}

pub fn first_seen_service_has_no_alert_test() {
  let status = ContainerStatus(Valheim, "running", 0, NoHealthcheck)
  let #(state, alerts) = check_status(status, Error(Nil))

  assert alerts == []
  assert state.last_state == "running"
  assert state.last_health == NoHealthcheck
  assert state.last_restart_count == 0
  assert state.alerted_restart == False
}

pub fn running_to_exited_alerts_test() {
  let prev = ServiceState("running", NoHealthcheck, 0, False)
  let status = ContainerStatus(Valheim, "exited", 0, NoHealthcheck)
  let #(state, alerts) = check_status(status, Ok(prev))

  assert alerts
    == [
      "🌲 **Valheim** vient de passer à l'état `exited`\n"
      <> "État précédent : `running`\n"
      <> "Redémarrages Docker : 0",
    ]
  assert state.last_state == "exited"
}

pub fn exited_to_running_sends_recovery_message_test() {
  let prev = ServiceState("exited", NoHealthcheck, 0, False)
  let status = ContainerStatus(Valheim, "running", 0, NoHealthcheck)
  let #(state, alerts) = check_status(status, Ok(prev))

  assert alerts == ["✅ **Valheim** est de nouveau `running` (était `exited`)"]
  assert state.last_state == "running"
}

pub fn a_service_without_healthcheck_never_alerts_on_health_test() {
  // Un service dont le healthcheck a disparu (ex: recréé sans health) ne
  // doit jamais déclencher d'alerte santé, même si l'état mémorisé diffère.
  let prev = ServiceState("running", Healthy, 0, False)
  let status = ContainerStatus(Valheim, "running", 0, NoHealthcheck)
  let #(state, alerts) = check_status(status, Ok(prev))

  assert alerts == []
  assert state.last_health == Healthy
}

pub fn becoming_unhealthy_while_running_alerts_test() {
  let prev = ServiceState("running", Healthy, 0, False)
  let status = ContainerStatus(Valheim, "running", 0, Unhealthy)
  let #(state, alerts) = check_status(status, Ok(prev))

  assert alerts
    == [
      "❤️‍🩹 **Valheim** est `unhealthy` !\n"
      <> "Vérifie les logs : `docker logs --tail 50 valheim`",
    ]
  assert state.last_health == Unhealthy
}

pub fn recovering_to_healthy_while_running_alerts_test() {
  let prev = ServiceState("running", Unhealthy, 0, False)
  let status = ContainerStatus(Valheim, "running", 0, Healthy)
  let #(state, alerts) = check_status(status, Ok(prev))

  assert alerts == ["💚 **Valheim** est de nouveau `healthy`."]
  assert state.last_health == Healthy
}

pub fn health_change_while_not_running_never_alerts_test() {
  // Un conteneur arrêté volontairement garde souvent son dernier
  // healthcheck à "unhealthy" — ça n'a rien d'anormal, pas d'alerte.
  let prev = ServiceState("exited", Healthy, 0, False)
  let status = ContainerStatus(Valheim, "exited", 0, Unhealthy)
  let #(state, alerts) = check_status(status, Ok(prev))

  assert alerts == []
  assert state.last_health == Unhealthy
}

pub fn transitioning_through_starting_does_not_alert_test() {
  let prev = ServiceState("running", NoHealthcheck, 0, False)
  let status = ContainerStatus(Valheim, "running", 0, Starting)
  let #(state, alerts) = check_status(status, Ok(prev))

  assert alerts == []
  assert state.last_health == Starting
}

pub fn crash_loop_alerts_once_at_threshold_test() {
  let prev = ServiceState("running", NoHealthcheck, 2, False)
  let status = ContainerStatus(Valheim, "running", 3, NoHealthcheck)
  let #(state, alerts) = check_status(status, Ok(prev))

  assert alerts
    == [
      "🔁 **Valheim** a redémarré **3 fois** depuis son lancement.\n"
      <> "Il est peut-être dans une boucle de crash. Vérifie les logs :\n"
      <> "`docker logs --tail 50 valheim`",
    ]
  assert state.alerted_restart == True
}

pub fn crash_loop_does_not_repeat_until_state_changes_test() {
  let prev = ServiceState("running", NoHealthcheck, 3, True)
  let status = ContainerStatus(Valheim, "running", 4, NoHealthcheck)
  let #(state, alerts) = check_status(status, Ok(prev))

  assert alerts == []
  assert state.alerted_restart == True
}

pub fn a_state_change_resets_the_crash_loop_dedup_flag_test() {
  // Le compteur de redémarrages n'augmente pas ici : on isole l'effet du
  // changement d'état sur le flag de dédup, sans redéclencher l'alerte.
  let prev = ServiceState("running", NoHealthcheck, 3, True)
  let status = ContainerStatus(Valheim, "exited", 3, NoHealthcheck)
  let #(state, _alerts) = check_status(status, Ok(prev))

  assert state.alerted_restart == False

  // ...donc un nouveau franchissement du seuil peut alerter à nouveau.
  let status2 = ContainerStatus(Valheim, "exited", 5, NoHealthcheck)
  let #(_state2, alerts2) = check_status(status2, Ok(state))
  assert alerts2 != []
}

pub fn crash_loop_is_not_gated_on_state_being_running_test() {
  // Le v1 ne conditionne pas la détection de crash-loop à state == "running".
  let prev = ServiceState("exited", NoHealthcheck, 2, False)
  let status = ContainerStatus(Cloudflared, "exited", 3, NoHealthcheck)
  let #(_state, alerts) = check_status(status, Ok(prev))

  assert alerts != []
}
