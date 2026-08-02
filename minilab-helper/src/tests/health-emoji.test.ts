import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { HealthStatus } from "../commons/types/health-status";
import { healthEmoji } from "../commons/helpers/health-emoji";

describe("healthEmoji", () => {
  it("maps every HealthStatus member to a distinct emoji", () => {
    assert.equal(healthEmoji(HealthStatus.Healthy), "💚");
    assert.equal(healthEmoji(HealthStatus.Unhealthy), "❤️‍🩹");
    assert.equal(healthEmoji(HealthStatus.Starting), "⏳");
    assert.equal(healthEmoji(HealthStatus.None), "⬜");
  });
});
