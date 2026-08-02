import { describe, it } from "node:test";
import assert from "node:assert/strict";
import type { WireGuardState } from "../managers/wireguard-manager/types/wireguard-state";
import { getAllPeers } from "../managers/wireguard-manager/internals/get-all-peers";

function state(overrides: Partial<WireGuardState> = {}): WireGuardState {
  return {
    seenHandshakes: new Map(),
    connectedPeers: new Set(),
    peerNames: new Map(),
    ...overrides,
  };
}

describe("getAllPeers", () => {
  it("returns every configured peer, connected or not", () => {
    const peers = getAllPeers(
      state({
        peerNames: new Map([
          ["pub-a", "Alice"],
          ["pub-b", "Bob"],
        ]),
        connectedPeers: new Set(["pub-a"]),
        seenHandshakes: new Map([["pub-a", 1_700_000_000]]),
      })
    );

    assert.deepEqual(peers, [
      { name: "Alice", connected: true, lastHandshake: new Date(1_700_000_000 * 1000) },
      { name: "Bob", connected: false, lastHandshake: null },
    ]);
  });

  it("returns an empty array when no peer is configured", () => {
    assert.deepEqual(getAllPeers(state()), []);
  });
});
