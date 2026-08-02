import type { ChatInputCommandInteraction } from "discord.js";

export function isOwner(interaction: ChatInputCommandInteraction, ownerId: string): boolean {
  return interaction.user.id === ownerId;
}
