import dictionaries/docker_services_dictionary/docker_services_dictionary
import dictionaries/docker_services_dictionary/types/service_name.{
  type ServiceName,
}
import dictionaries/service_categories_dictionary/derived/category_order
import dictionaries/service_categories_dictionary/types/service_category.{
  type ServiceCategory,
}
import gleam/list

pub fn group_by_category(
  services: List(ServiceName),
) -> List(#(ServiceCategory, List(ServiceName))) {
  category_order.category_order()
  |> list.map(fn(category) {
    #(
      category,
      list.filter(services, fn(service) {
        docker_services_dictionary.get_service(service).category == category
      }),
    )
  })
  |> list.filter(fn(pair) { pair.1 != [] })
}
