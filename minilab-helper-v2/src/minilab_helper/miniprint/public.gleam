import minilab_helper/miniprint/private
import minilab_helper/miniprint/types.{type MiniPrintOverview}

/// Aperçu à la demande de MiniPrint (Klipper/Moonraker + Mainsail +
/// Crowsnest). Pas de polling associé — équivalent de
/// miniprint-manager.ts's getOverview.
pub fn get_overview() -> MiniPrintOverview {
  private.get_overview()
}
