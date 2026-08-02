import type { ServiceName } from "../types/service-name";
import type { ServiceCategory } from "../../service-categories-dictionnary/types/service-category";
import { SERVICES } from "../docker-services-dictionnary";
import { CATEGORY_ORDER } from "../../service-categories-dictionnary/derived/category-order";

export function groupByCategory(services: ServiceName[]): Map<ServiceCategory, ServiceName[]> {
  const map = new Map<ServiceCategory, ServiceName[]>();
  for (const cat of CATEGORY_ORDER) map.set(cat, []);
  for (const s of services) {
    const cat = SERVICES[s].category;
    map.get(cat)!.push(s);
  }

  for (const [cat, list] of map) {
    if (list.length === 0) map.delete(cat);
  }

  return map;
}
