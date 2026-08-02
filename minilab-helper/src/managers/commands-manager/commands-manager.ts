import { Client, REST, Routes } from "discord.js";
import { buildSlashCommands } from "../../dictionnaries/command-dictionary/derived/build-slash-commands";
import type { CommandName } from "../../dictionnaries/command-dictionary/types/command-name";
import { COMMAND_HANDLERS } from "./internals/command-handlers";
import { isOwner } from "./internals/helpers/is-owner";
import { rejectUnauthorized } from "./internals/helpers/reject-unauthorized";

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

      const handler = COMMAND_HANDLERS[interaction.commandName as CommandName];
      if (!handler) return;

      try {
        await handler(interaction);
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
