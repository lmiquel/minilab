import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { formatUptime } from "../managers/commands-manager/internals/helpers/format-uptime";

describe("formatUptime", () => {
  it("formats minutes only when under an hour", () => {
    assert.equal(formatUptime(0), "0min");
    assert.equal(formatUptime(59), "0min");
    assert.equal(formatUptime(90), "1min");
    assert.equal(formatUptime(3_599), "59min");
  });

  it("formats hours and minutes when under a day", () => {
    assert.equal(formatUptime(3_600), "1h 0min");
    assert.equal(formatUptime(3_660), "1h 1min");
    assert.equal(formatUptime(86_399), "23h 59min");
  });

  it("formats days and hours once over a day", () => {
    assert.equal(formatUptime(86_400), "1j 0h");
    assert.equal(formatUptime(90_000), "1j 1h");
    assert.equal(formatUptime(2 * 86_400 + 5 * 3_600), "2j 5h");
  });
});
