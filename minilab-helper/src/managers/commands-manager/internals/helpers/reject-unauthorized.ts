import type { ChatInputCommandInteraction } from "discord.js";

export async function rejectUnauthorized(interaction: ChatInputCommandInteraction): Promise<void> {
  await interaction.reply({ content: "🚫 Tu n'es pas autorisé à utiliser cette commande.", ephemeral: true });
}
