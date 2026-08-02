import dictionaries/service_categories_dictionary/types/service_category.{
  type ServiceCategory,
}

pub type ServiceDefinition {
  ServiceDefinition(
    container_name: String,
    label: String,
    emoji: String,
    category: ServiceCategory,
    controllable: Bool,
    monitored: Bool,
  )
}
