import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { formatDateFr } from "../commons/helpers/format-date-fr";

describe("formatDateFr", () => {
  it("formats in French dd/mm/yyyy, converted to Europe/Paris time", () => {
    // Hiver : Europe/Paris = UTC+1
    assert.equal(formatDateFr(new Date("2024-01-15T12:00:00Z")), "15/01/2024 13:00:00");
    // Été : Europe/Paris = UTC+2 (DST)
    assert.equal(formatDateFr(new Date("2024-07-15T12:00:00Z")), "15/07/2024 14:00:00");
  });
});
