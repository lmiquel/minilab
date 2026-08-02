import { Client, REST, Routes } from "discord.js";
import { buildSlashCommands } from "./internals/build-slash-commands";
import { handleMiniPrint } from "./internals/handle-miniprint";
import { handleOverview } from "./internals/handle-overview";
import { handleResources } from "./internals/handle-resources";
import { handleRestart } from "./internals/handle-restart";
import { handleShutdown } from "./internals/handle-shutdown";
import { handleStart } from "./internals/handle-start";
import { handleStatus } from "./internals/handle-status";
import { handleStop } from "./internals/handle-stop";
import { handleVpn } from "./internals/handle-vpn";
import { isOwner } from "./internals/helpers/is-owner";
import { rejectUnauthorized } from "./internals/helpers/reject-unauthorized";
import { CommandName } from "./types/command-name";

const OWNER_ID = process.env.DISCORD_OWNER_ID!;

class CommandsManager {
  async registerCommands(token: string, clientId: string): Promise<void> {
    const rest = new REST({ version: "10" }).setToken(token);
    await rest.put(Routes.applicationCommands(clientId), { body: buildSlashCommands() });
    console.log("[Commands] Commandes slash enregistrées globalement.");
  }

  setupCommandHandler(client: Client): void {
    client.on("interactionCreate", async (interaction) => {
      if (!interaction.isChatInputCommand()) return;
      if (!isOwner(interaction, OWNER_ID)) {
        await rejectUnauthorized(interaction);
        return;
      }

      try {
        switch (interaction.commandName) {
          case CommandName.Overview:
            await handleOverview(interaction);
            break;
          case CommandName.Status:
            await handleStatus(interaction);
            break;
          case CommandName.Stop:
            await handleStop(interaction);
            break;
          case CommandName.Start:
            await handleStart(interaction);
            break;
          case CommandName.Restart:
            await handleRestart(interaction);
            break;
          case CommandName.Resources:
            await handleResources(interaction);
            break;
          case CommandName.Vpn:
            await handleVpn(interaction);
            break;
          case CommandName.MiniPrint:
            await handleMiniPrint(interaction);
            break;
          case CommandName.Shutdown:
            await handleShutdown(interaction);
            break;
        }
      } catch (err) {
        console.error(`[Commands] Erreur sur /${interaction.commandName}:`, err);
        const msg = "❌ Une erreur est survenue lors de l'exécution de la commande.";
        if (interaction.replied || interaction.deferred) await interaction.editReply(msg);
        else await interaction.reply({ content: msg, ephemeral: true });
      }
    });
  }
}

export const commandsManager = new CommandsManager();
