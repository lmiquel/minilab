import type { ThrottledState } from "./throttled-state";
import type { PrinterStorageInfo } from "./printer-storage-info";
import type { KlippyState } from "./klippy-state";

export interface MiniPrintOverview {
  /** true si Moonraker OU Mainsail a répondu (au moins un signe de vie) */
  reachable: boolean;
  cpuTempC: number | null;
  cpuPercent: number | null;
  moonrakerMemMB: number | null;
  totalMemMB: number | null;
  uptimeSec: number | null;
  /** État vcgencmd brut (sous-tension, bridage thermique…), null si indisponible */
  throttled: ThrottledState | null;
  storage: PrinterStorageInfo | null;
  mainsailUp: boolean;
  moonrakerUp: boolean;
  klippyConnected: boolean;
  /** null si injoignable */
  klippyState: KlippyState | null;
  crowsnestUp: boolean;
}
