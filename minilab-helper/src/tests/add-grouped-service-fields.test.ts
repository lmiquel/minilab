import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { EmbedBuilder } from "discord.js";
import { ALL_SERVICES } from "../dictionaries/docker-services-dictionary/derived/all-services";
import { SERVICES } from "../dictionaries/docker-services-dictionary/docker-services-dictionary";
import { addGroupedServiceFields } from "../managers/commands-manager/internals/helpers/add-grouped-service-fields";

describe("addGroupedServiceFields", () => {
  it("adds a category header field plus one field per service", async () => {
    const [a, b] = ALL_SERVICES;
    const sameCategory = ALL_SERVICES.filter((s) => SERVICES[s].category === SERVICES[a].category);
    const embed = new EmbedBuilder();

    await addGroupedServiceFields(embed, sameCategory, (service) => `value-${service}`);

    const fields = embed.toJSON().fields ?? [];
    // 1 champ d'en-tête de catégorie + 1 champ par service de cette catégorie.
    assert.equal(fields.length, 1 + sameCategory.length);
    assert.equal(fields[0].inline, false);
    for (const service of sameCategory) {
      const field = fields.find((f) => f.name === `${SERVICES[service].emoji} ${SERVICES[service].label}`);
      assert.ok(field, `expected a field for ${service}`);
      assert.equal(field!.value, `value-${service}`);
      assert.equal(field!.inline, true);
    }
    void b;
  });

  it("skips a service when buildValue returns null", async () => {
    const [a, b] = ALL_SERVICES;
    const embed = new EmbedBuilder();

    await addGroupedServiceFields(embed, [a, b], (service) => (service === a ? null : "kept"));

    const fields = embed.toJSON().fields ?? [];
    assert.ok(!fields.some((f) => f.name === `${SERVICES[a].emoji} ${SERVICES[a].label}`));
    assert.ok(fields.some((f) => f.name === `${SERVICES[b].emoji} ${SERVICES[b].label}`));
  });

  it("awaits an async buildValue", async () => {
    const [a] = ALL_SERVICES;
    const embed = new EmbedBuilder();

    await addGroupedServiceFields(embed, [a], async (service) => {
      await new Promise((resolve) => setTimeout(resolve, 1));
      return `async-${service}`;
    });

    const fields = embed.toJSON().fields ?? [];
    assert.equal(fields.at(-1)?.value, `async-${a}`);
  });

  it("adds nothing beyond the base embed for an empty service list", async () => {
    const embed = new EmbedBuilder();
    await addGroupedServiceFields(embed, [], () => "unused");
    assert.deepEqual(embed.toJSON().fields ?? [], []);
  });
});
