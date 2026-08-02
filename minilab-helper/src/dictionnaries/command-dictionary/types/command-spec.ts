import type { SlashCommandBuilder, SlashCommandOptionsOnlyBuilder } from "discord.js";

export interface CommandSpec {
  build: () => SlashCommandBuilder | SlashCommandOptionsOnlyBuilder;
}
