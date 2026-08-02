export interface PeerInfo {
  name: string;
  connected: boolean;
  lastHandshake: Date | null; // null = jamais connecté
}
