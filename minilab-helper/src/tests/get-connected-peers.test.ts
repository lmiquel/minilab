import { describe, it } from "node:test";
import assert from "node:assert/strict";
import type { WireGuardState } from "../managers/wireguard-manager/types/wireguard-state";
import { getConnectedPeers } from "../managers/wireguard-manager/internals/get-connected-peers";

function state(overrides: Partial<WireGuardState> = {}): WireGuardState {
  return {
    seenHandshakes: new Map(),
    connectedPeers: new Set(),
    peerNames: new Map(),
    ...overrides,
  };
}

describe("getConnectedPeers", () => {
  it("only returns currently connected peers, with their last handshake date", () => {
    const peers = getConnectedPeers(
      state({
        peerNames: new Map([
          ["pub-a", "Alice"],
          ["pub-b", "Bob"],
        ]),
        connectedPeers: new Set(["pub-a"]),
        seenHandshakes: new Map([["pub-a", 1_700_000_000]]),
      })
    );

    assert.deepEqual(peers, [{ name: "Alice", since: new Date(1_700_000_000 * 1000) }]);
  });

  it("falls back to a placeholder name for an unmapped pubkey", () => {
    const peers = getConnectedPeers(state({ connectedPeers: new Set(["deadbeefdeadbeefdeadbeef"]) }));

    assert.equal(peers.length, 1);
    assert.match(peers[0].name, /^clé inconnue /);
  });

  it("returns an empty array when nobody is connected", () => {
    assert.deepEqual(getConnectedPeers(state()), []);
  });
});
