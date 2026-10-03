export const SUPPORTED_LOCALES = ["fr", "en", "de", "es"] as const;
export const FALLBACK_LOCALE = "en";

const LOCALE_NAMES: Record<(typeof SUPPORTED_LOCALES)[number], string> = {
  fr: "French",
  en: "English",
  de: "German",
  es: "Spanish",
};

export function normalizeLocale(value: unknown): (typeof SUPPORTED_LOCALES)[number] {
  const raw = String(value ?? "")
    .trim()
    .toLowerCase()
    .replace("_", "-");
  if (!raw) {
    return FALLBACK_LOCALE;
  }
  const code = raw.split("-", 1)[0] ?? FALLBACK_LOCALE;
  if ((SUPPORTED_LOCALES as readonly string[]).includes(code)) {
    return code as (typeof SUPPORTED_LOCALES)[number];
  }
  return FALLBACK_LOCALE;
}

export function localeLanguageName(value: unknown): string {
  return LOCALE_NAMES[normalizeLocale(value)];
}
