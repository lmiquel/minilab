import type { MiniPrintOverview } from "../../commons/types/miniprint-overview";
import { getMiniPrintOverview } from "./internals/get-miniprint-overview";

const PEER_NAME = "MiniPrint";

class MiniPrintManager {
  readonly peerName = PEER_NAME;

  getOverview(): Promise<MiniPrintOverview> {
    return getMiniPrintOverview();
  }
}

export const miniPrintManager = new MiniPrintManager();
