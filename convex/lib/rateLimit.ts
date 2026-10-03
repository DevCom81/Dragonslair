export const DEFAULT_PER_MINUTE = 30;
export const DEFAULT_PER_HOUR = 300;

export function envLimit(name: string, defaultValue: number): number {
  const raw = (process.env[name] ?? "").trim();
  if (!raw) {
    return defaultValue;
  }
  const value = Number.parseInt(raw, 10);
  return Number.isFinite(value) ? value : defaultValue;
}

export function rateLimitExceeded(args: {
  hits: number[];
  now: number;
  perMinute: number;
  perHour: number;
}): boolean {
  if (args.perMinute <= 0 && args.perHour <= 0) {
    return false;
  }
  const hourCut = args.now - 3_600_000;
  const minuteCut = args.now - 60_000;
  const inHour = args.hits.filter((stamp) => stamp > hourCut);
  const minuteCount = inHour.filter((stamp) => stamp > minuteCut).length;
  const hourCount = inHour.length;
  const overMinute = args.perMinute > 0 && minuteCount >= args.perMinute;
  const overHour = args.perHour > 0 && hourCount >= args.perHour;
  return overMinute || overHour;
}
