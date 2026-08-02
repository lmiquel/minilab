export interface WireGuardState {
  seenHandshakes: Map<string, number>; // pubkey → timestamp dernier handshake
  connectedPeers: Set<string>; // pubkeys actuellement connectés
  peerNames: Map<string, string>; // pubkey → nom
}
