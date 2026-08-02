export function formatDateFr(date: Date): string {
  return date.toLocaleString("fr-FR", { timeZone: "Europe/Paris" });
}
