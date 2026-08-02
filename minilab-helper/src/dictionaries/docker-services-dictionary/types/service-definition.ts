import type { ServiceCategory } from "../../service-categories-dictionary/types/service-category";

export interface ServiceDefinition {
  containerName: string;
  label: string;
  emoji: string;
  category: ServiceCategory;
  controllable: boolean;
  monitored: boolean;
}
