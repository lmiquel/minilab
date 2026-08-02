import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { tempEmoji } from "../managers/commands-manager/internals/helpers/temp-emoji";

describe("tempEmoji", () => {
  it("returns green under 60°C", () => {
    assert.equal(tempEmoji(0), "🟢");
    assert.equal(tempEmoji(59), "🟢");
  });

  it("returns yellow between 60°C and 69°C", () => {
    assert.equal(tempEmoji(60), "🟡");
    assert.equal(tempEmoji(69), "🟡");
  });

  it("returns red at 70°C and above", () => {
    assert.equal(tempEmoji(70), "🔴");
    assert.equal(tempEmoji(100), "🔴");
  });
});
