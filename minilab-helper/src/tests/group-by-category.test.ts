import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { SERVICES } from "../dictionaries/docker-services-dictionary/docker-services-dictionary";
import { ALL_SERVICES } from "../dictionaries/docker-services-dictionary/derived/all-services";
import { CATEGORY_ORDER } from "../dictionaries/service-categories-dictionary/derived/category-order";
import { groupByCategory } from "../dictionaries/docker-services-dictionary/derived/group-by-category";

describe("groupByCategory", () => {
  it("puts every service under its own category, respecting CATEGORY_ORDER", () => {
    const grouped = groupByCategory(ALL_SERVICES);

    // Chaque catégorie présente respecte l'ordre global, et ne contient que
    // des services qui lui appartiennent réellement.
    const seenCategories = [...grouped.keys()];
    const expectedOrder = CATEGORY_ORDER.filter((cat) => seenCategories.includes(cat));
    assert.deepEqual(seenCategories, expectedOrder);

    for (const [cat, services] of grouped) {
      for (const service of services) {
        assert.equal(SERVICES[service].category, cat);
      }
    }

    // Chaque service d'entrée se retrouve exactement une fois au total.
    const flattened = [...grouped.values()].flat();
    assert.deepEqual([...flattened].sort(), [...ALL_SERVICES].sort());
  });

  it("omits categories with no matching service instead of returning an empty list", () => {
    const [oneService] = ALL_SERVICES;
    const grouped = groupByCategory([oneService]);

    assert.equal(grouped.size, 1);
    assert.deepEqual(grouped.get(SERVICES[oneService].category), [oneService]);
  });

  it("returns an empty map for an empty input", () => {
    assert.equal(groupByCategory([]).size, 0);
  });
});
