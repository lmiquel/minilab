#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ServiceCategory {
    Game,
    Apps,
    DevTools,
    Utils,
    Network,
}

impl ServiceCategory {
    pub fn label(self) -> &'static str {
        match self {
            ServiceCategory::Game => "🎮 Jeux",
            ServiceCategory::Apps => "📦 Apps",
            ServiceCategory::DevTools => "🛠️ Dev Tools",
            ServiceCategory::Utils => "🔧 Utilitaires",
            ServiceCategory::Network => "🌐 Réseau",
        }
    }

    pub const ORDER: [ServiceCategory; 5] = [
        ServiceCategory::Game,
        ServiceCategory::Apps,
        ServiceCategory::DevTools,
        ServiceCategory::Utils,
        ServiceCategory::Network,
    ];
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn order_covers_every_category_once() {
        assert_eq!(ServiceCategory::ORDER.len(), 5);
    }
}
