import type { SlashCommandStringOption } from "discord.js";
import { SlashCommandBuilder } from "discord.js";
import { CommandName } from "./types/command-name";
import type { CommandSpec } from "./types/command-spec";
import { CONTROLLABLE_SERVICES } from "../docker-services-dictionary/derived/controllable-services";
import { toDiscordChoices } from "../docker-services-dictionary/derived/to-discord-choices";

const SERVICE_CHOICES = toDiscordChoices(CONTROLLABLE_SERVICES);

const serviceOption = (description: string) => (opt: SlashCommandStringOption) =>
  opt.setName("service").setDescription(description).setRequired(true).addChoices(...SERVICE_CHOICES);

export const COMMAND_DEFINITIONS: Record<CommandName, CommandSpec> = {
  [CommandName.Overview]: {
    build: () =>
      new SlashCommandBuilder()
        .setName(CommandName.Overview)
        .setDescription("Vue d'ensemble du minilab : statut, ressources et VPN"),
  },

  [CommandName.Status]: {
    build: () =>
      new SlashCommandBuilder()
        .setName(CommandName.Status)
        .setDescription("Affiche le statut de tous les services minilab"),
  },

  [CommandName.Stop]: {
    build: () =>
      new SlashCommandBuilder()
        .setName(CommandName.Stop)
        .setDescription("Arrête un service")
        .addStringOption(serviceOption("Le service à arrêter")),
  },

  [CommandName.Start]: {
    build: () =>
      new SlashCommandBuilder()
        .setName(CommandName.Start)
        .setDescription("Démarre un service")
        .addStringOption(serviceOption("Le service à démarrer")),
  },

  [CommandName.Restart]: {
    build: () =>
      new SlashCommandBuilder()
        .setName(CommandName.Restart)
        .setDescription("Redémarre un service")
        .addStringOption(serviceOption("Le service à redémarrer")),
  },

  [CommandName.Resources]: {
    build: () =>
      new SlashCommandBuilder()
        .setName(CommandName.Resources)
        .setDescription("Affiche la consommation CPU/RAM et la température du RPi"),
  },

  [CommandName.Vpn]: {
    build: () =>
      new SlashCommandBuilder()
        .setName(CommandName.Vpn)
        .setDescription("Affiche les peers WireGuard actuellement connectés"),
  },

  [CommandName.MiniPrint]: {
    build: () =>
      new SlashCommandBuilder()
        .setName(CommandName.MiniPrint)
        .setDescription("Statut de MiniPrint : température, ressources, Klipper/Mainsail/Crowsnest"),
  },

  [CommandName.Shutdown]: {
    build: () =>
      new SlashCommandBuilder()
        .setName(CommandName.Shutdown)
        .setDescription("⚠️  Éteint complètement le Raspberry Pi (arrête tous les services d'abord)"),
  },
};
