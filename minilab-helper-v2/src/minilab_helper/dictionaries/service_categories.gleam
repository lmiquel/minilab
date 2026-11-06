pub type ServiceCategory {
  Game
  Apps
  DevTools
  Interface
  Utils
  Network
}

pub fn category_label(category: ServiceCategory) -> String {
  case category {
    Game -> "🎮 Jeux"
    Apps -> "📦 Apps"
    DevTools -> "🛠️ Dev Tools"
    Interface -> "🖥️ Interface"
    Utils -> "🔧 Utilitaires"
    Network -> "🌐 Réseau"
  }
}

pub fn category_order() -> List(ServiceCategory) {
  [Game, Apps, DevTools, Interface, Utils, Network]
}
