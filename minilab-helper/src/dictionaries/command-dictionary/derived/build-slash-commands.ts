import { COMMAND_DEFINITIONS } from "../command-dictionary";

export function buildSlashCommands() {
  return Object.values(COMMAND_DEFINITIONS).map((command) => command.build().toJSON());
}
