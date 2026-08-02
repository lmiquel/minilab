import { SlashCommandBuilder } from "discord.js";
import { CommandName } from "../types/command-name";
import { CONTROLLABLE_SERVICES } from "../../../dictionnaries/docker-services-dictionnary/derived/controllable-services";
import { toDiscordChoices } from "../../../dictionnaries/docker-services-dictionnary/derived/to-discord-choices";

export function buildSlashCommands() {
  const SERVICE_CHOICES = toDiscordChoices(CONTROLLABLE_SERVICES);

  return [
    new SlashCommandBuilder()
      .setName(CommandName.Overview)
      .setDescription("Vue d'ensemble du minilab : statut, ressources et VPN"),

    new SlashCommandBuilder()
      .setName(CommandName.Status)
      .setDescription("Affiche le statut de tous les services minilab"),

    new SlashCommandBuilder()
      .setName(CommandName.Stop)
      .setDescription("Arrête un service")
      .addStringOption((opt) =>
        opt.setName("service").setDescription("Le service à arrêter").setRequired(true).addChoices(...SERVICE_CHOICES)
      ),

    new SlashCommandBuilder()
      .setName(CommandName.Start)
      .setDescription("Démarre un service")
      .addStringOption((opt) =>
        opt.setName("service").setDescription("Le service à démarrer").setRequired(true).addChoices(...SERVICE_CHOICES)
      ),

    new SlashCommandBuilder()
      .setName(CommandName.Restart)
      .setDescription("Redémarre un service")
      .addStringOption((opt) =>
        opt.setName("service").setDescription("Le service à redémarrer").setRequired(true).addChoices(...SERVICE_CHOICES)
      ),

    new SlashCommandBuilder()
      .setName(CommandName.Resources)
      .setDescription("Affiche la consommation CPU/RAM et la température du RPi"),

    new SlashCommandBuilder()
      .setName(CommandName.Vpn)
      .setDescription("Affiche les peers WireGuard actuellement connectés"),

    new SlashCommandBuilder()
      .setName(CommandName.MiniPrint)
      .setDescription("Statut de MiniPrint : température, ressources, Klipper/Mainsail/Crowsnest"),

    new SlashCommandBuilder()
      .setName(CommandName.Shutdown)
      .setDescription("⚠️  Éteint complètement le Raspberry Pi (arrête tous les services d'abord)"),
  ].map((cmd) => cmd.toJSON());
}
