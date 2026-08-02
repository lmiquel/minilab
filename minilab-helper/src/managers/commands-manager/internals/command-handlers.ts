import type { ChatInputCommandInteraction } from "discord.js";
import { CommandName } from "../../../dictionaries/command-dictionary/types/command-name";
import { handleMiniPrint } from "./handlers/handle-miniprint";
import { handleOverview } from "./handlers/handle-overview";
import { handleResources } from "./handlers/handle-resources";
import { handleRestart } from "./handlers/handle-restart";
import { handleShutdown } from "./handlers/handle-shutdown";
import { handleStart } from "./handlers/handle-start";
import { handleStatus } from "./handlers/handle-status";
import { handleStop } from "./handlers/handle-stop";
import { handleVpn } from "./handlers/handle-vpn";

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
