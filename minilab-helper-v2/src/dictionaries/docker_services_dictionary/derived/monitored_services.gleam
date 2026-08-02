import dictionaries/docker_services_dictionary/docker_services_dictionary
import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName,
}
import gleam/list

pub fn monitored_services() -> List(ServiceName) {
  docker_services_dictionary.services()
  |> list.filter(fn(pair) { pair.1.monitored })
  |> list.map(fn(pair) { pair.0 })
}
