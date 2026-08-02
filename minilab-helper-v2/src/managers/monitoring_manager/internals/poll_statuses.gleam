import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName,
}
import gleam/dict.{type Dict}
import gleam/list
import gleam/string
import managers/docker_manager/docker_manager
import managers/monitoring_manager/internals/check_status
import managers/monitoring_manager/types/service_state.{type ServiceState}

/// Un cycle de polling : récupère les statuts, diffuse les alertes en DM,
/// renvoie l'état à mémoriser pour le prochain cycle. Port de poll-statuses.ts.
pub fn poll_statuses(
  client: docker_manager.Client,
  states: Dict(ServiceName, ServiceState),
  dm: fn(String) -> Nil,
) -> Dict(ServiceName, ServiceState) {
  case docker_manager.get_all_statuses(client) {
    Error(err) -> {
      dm(
        "⚠️ **Une erreur docker est survenue !**\n**"
        <> string.inspect(err)
        <> "**",
      )
      states
    }

    Ok(statuses) ->
      list.fold(statuses, states, fn(acc, status) {
        let previous = dict.get(acc, status.name)
        let #(new_state, alerts) = check_status.check_status(status, previous)
        list.each(alerts, dm)
        dict.insert(acc, status.name, new_state)
      })
  }
}
