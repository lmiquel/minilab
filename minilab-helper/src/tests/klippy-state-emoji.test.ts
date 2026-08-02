import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { KlippyState } from "../commons/types/klippy-state";
import { klippyStateEmoji } from "../managers/commands-manager/internals/helpers/klippy-state-emoji";

describe("klippyStateEmoji", () => {
  it("returns green when ready", () => {
    assert.equal(klippyStateEmoji(KlippyState.Ready), "🟢");
  });

  it("returns yellow on startup", () => {
    assert.equal(klippyStateEmoji(KlippyState.Startup), "🟡");
  });

  it("returns red on shutdown or error", () => {
    assert.equal(klippyStateEmoji(KlippyState.Shutdown), "🔴");
    assert.equal(klippyStateEmoji(KlippyState.Error), "🔴");
  });

  it("returns black when unreachable (null)", () => {
    assert.equal(klippyStateEmoji(null), "⚫");
  });
});
