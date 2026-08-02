/** Lit la température du RPi en °C */
export async function getRpiTemperature(): Promise<number> {
  const fs = await import("fs/promises");
  const raw = await fs.readFile("/sys/class/thermal/thermal_zone0/temp", "utf-8");
  return Math.round(parseInt(raw.trim(), 10) / 1000);
}
