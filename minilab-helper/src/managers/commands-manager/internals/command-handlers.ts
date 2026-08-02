import type { ChatInputCommandInteraction } from "discord.js";
import { CommandName } from "../../../dictionnaries/command-dictionary/types/command-name";
import { handleOverview } from "./handlers/handle-overview";
import { handleStatus } from "./handlers/handle-status";
import { handleStop } from "./handlers/handle-stop";
import { handleStart } from "./handlers/handle-start";
import { handleRestart } from "./handlers/handle-restart";
import { handleResources } from "./handlers/handle-resources";
import { handleVpn } from "./handlers/handle-vpn";
import { handleMiniPrint } from "./handlers/handle-miniprint";
import { handleShutdown } from "./handlers/handle-shutdown";

export const COMMAND_HANDLERS: Record<CommandName, (interaction: ChatInputCommandInteraction) => Promise<void>> = {
  [CommandName.Overview]: handleOverview,
  [CommandName.Status]: handleStatus,
  [CommandName.Stop]: handleStop,
  [CommandName.Start]: handleStart,
  [CommandName.Restart]: handleRestart,
  [CommandName.Resources]: handleResources,
  [CommandName.Vpn]: handleVpn,
  [CommandName.MiniPrint]: handleMiniPrint,
  [CommandName.Shutdown]: handleShutdown,
};
