import dictionaries/service_categories_dictionary/types/service_category.{
  type ServiceCategory, Apps, Game, Network, Utils,
}

pub fn category_order() -> List(ServiceCategory) {
  [Game, Apps, Utils, Network]
}
