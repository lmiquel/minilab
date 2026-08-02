import type { ServiceCategory } from "../types/service-category";
import { CATEGORY_LABELS } from "../service-categories-dictionnary";

export const CATEGORY_ORDER: ServiceCategory[] = Object.keys(CATEGORY_LABELS) as ServiceCategory[];
