pub type ServiceCategory {
  Game
  Apps
  Utils
  Network
}

pub fn category_label(category: ServiceCategory) -> String {
  case category {
    Game -> "🎮 Jeux"
    Apps -> "📦 Apps"
    Utils -> "🔧 Utilitaires"
    Network -> "🌐 Réseau"
  }
}

pub fn category_order() -> List(ServiceCategory) {
  [Game, Apps, Utils, Network]
}
