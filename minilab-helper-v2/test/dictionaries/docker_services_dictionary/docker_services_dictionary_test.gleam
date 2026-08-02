import dictionaries/docker_services_dictionary/derived/all_services.{
  all_services,
}
import dictionaries/docker_services_dictionary/docker_services_dictionary.{
  service_name_from_string, service_name_to_string,
}
import gleam/list

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
