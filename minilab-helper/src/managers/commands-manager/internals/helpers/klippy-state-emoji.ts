import { KlippyState } from "../../../../commons/types/klippy-state";

export function klippyStateEmoji(state: KlippyState | null): string {
  switch (state) {
    case KlippyState.Ready:
      return "🟢";
    case KlippyState.Startup:
      return "🟡";
    case KlippyState.Shutdown:
    case KlippyState.Error:
      return "🔴";
    default:
      return "⚫"; // injoignable / inconnu
  }
}
