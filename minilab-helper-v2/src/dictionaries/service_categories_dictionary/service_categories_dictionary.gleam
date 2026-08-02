import dictionaries/service_categories_dictionary/types/service_category.{
  type ServiceCategory, Apps, Game, Network, Utils,
}

pub fn category_label(category: ServiceCategory) -> String {
  case category {
    Game -> "🎮 Jeux"
    Apps -> "📦 Apps"
    Utils -> "🔧 Utilitaires"
    Network -> "🌐 Réseau"
  }
}
