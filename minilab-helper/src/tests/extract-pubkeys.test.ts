import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { extractPubkeys } from "../managers/wireguard-manager/internals/extract-pubkeys";

// Une clé WireGuard valide fait 43 caractères base64 + un "=" de padding.
const KEY_A = "A".repeat(43) + "=";
const KEY_B = "B".repeat(43) + "=";

describe("extractPubkeys", () => {
  it("extracts valid base64 WireGuard public keys, one per line", () => {
    assert.deepEqual(extractPubkeys([KEY_A, KEY_B].join("\n")), [KEY_A, KEY_B]);
  });

  it("ignores lines that aren't exactly a 44-char base64 key", () => {
    const output = [`peer: ${KEY_A}`, "tooshort=", KEY_B].join("\n");
    assert.deepEqual(extractPubkeys(output), [KEY_B]);
  });

  it("returns an empty array when there are no keys", () => {
    assert.deepEqual(extractPubkeys(""), []);
    assert.deepEqual(extractPubkeys("interface: wg0\npublic key: (hidden)\n"), []);
  });
});
