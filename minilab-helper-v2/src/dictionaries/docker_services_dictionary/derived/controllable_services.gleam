import dictionaries/docker_services_dictionary/docker_services_dictionary
import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName,
}
import gleam/list

pub fn controllable_services() -> List(ServiceName) {
  docker_services_dictionary.services()
  |> list.filter(fn(pair) { pair.1.controllable })
  |> list.map(fn(pair) { pair.0 })
}
