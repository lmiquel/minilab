export function extractPubkeys(output: string): string[] {
  return [...output.matchAll(/^([A-Za-z0-9+/]{43}=)$/gm)].map((m) => m[1]);
}
