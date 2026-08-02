export function tempEmoji(celsius: number): string {
  return celsius >= 70 ? "🔴" : celsius >= 60 ? "🟡" : "🟢";
}
