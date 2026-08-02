const FETCH_TIMEOUT_MS = 4_000;

export async function checkReachable(url: string): Promise<boolean> {
  try {
    await fetch(url, { method: "GET", signal: AbortSignal.timeout(FETCH_TIMEOUT_MS) });
    return true;
  } catch {
    return false;
  }
}
