SUPPORTED_LOCALES = ("fr", "en", "de", "es")
FALLBACK_LOCALE = "en"

_LOCALE_NAMES = {
    "fr": "French",
    "en": "English",
    "de": "German",
    "es": "Spanish",
}


def normalize_locale(value: object) -> str:
    raw = str(value or "").strip().lower().replace("_", "-")
    if not raw:
        return FALLBACK_LOCALE
    code = raw.split("-", 1)[0]
    if code in SUPPORTED_LOCALES:
        return code
    return FALLBACK_LOCALE


def locale_language_name(value: object) -> str:
    return _LOCALE_NAMES[normalize_locale(value)]
