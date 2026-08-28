from datetime import datetime, timezone
from typing import Any, Literal

BillingProvider = Literal["stripe", "google_play", "manual"]
SourceStatus = Literal[
    "active",
    "pending",
    "canceled",
    "expired",
    "on_hold",
    "revoked",
]

BILLING_PROVIDERS = {"stripe", "google_play", "manual"}
PURCHASE_PROVIDERS = {"stripe", "google_play"}
VALID_GRANT_STATUSES = {"active", "canceled"}
NEVER_GRANT_STATUSES = {"pending", "expired", "on_hold", "revoked"}
STATUS_ALIASES = {
    "cancelled": "canceled",
    "suspended": "on_hold",
    "refunded": "revoked",
}


def normalize_billing_provider(value: object) -> BillingProvider | None:
    raw = str(value or "").strip().lower()
    if raw in BILLING_PROVIDERS:
        return raw  # type: ignore[return-value]
    return None


def normalize_source_status(value: object) -> SourceStatus:
    raw = str(value or "").strip().lower()
    raw = STATUS_ALIASES.get(raw, raw)
    if raw in VALID_GRANT_STATUSES or raw in NEVER_GRANT_STATUSES:
        return raw  # type: ignore[return-value]
    return "pending"


def parse_timestamptz(value: object) -> datetime | None:
    if isinstance(value, datetime):
        parsed = value
    elif isinstance(value, str) and value.strip():
        raw = value.strip().replace("Z", "+00:00")
        try:
            parsed = datetime.fromisoformat(raw)
        except ValueError:
            return None
    else:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def source_grants_full(source: object, *, now: datetime | None = None) -> bool:
    if not isinstance(source, dict):
        return False
    status = normalize_source_status(source.get("status"))
    if status not in VALID_GRANT_STATUSES:
        return False
    clock = now or datetime.now(timezone.utc)
    period_end = parse_timestamptz(source.get("current_period_end"))
    if status == "canceled" and period_end is None:
        return False
    if period_end is not None and period_end <= clock:
        return False
    return True


def entitlement_row_is_full(row: object, *, now: datetime | None = None) -> bool:
    if not isinstance(row, dict):
        return False
    if str(row.get("access_level") or "").strip().lower() != "full":
        return False
    clock = now or datetime.now(timezone.utc)
    expires_at = parse_timestamptz(row.get("expires_at"))
    if expires_at is not None and expires_at <= clock:
        return False
    return True


def compute_global_entitlement(
    *,
    user_id: str,
    sources: list[Any],
    now: datetime | None = None,
) -> dict[str, Any]:
    """Merge all billing sources. Never use last webhook alone to set global access."""
    clock = now or datetime.now(timezone.utc)
    valid: list[dict[str, Any]] = []
    for item in sources:
        if isinstance(item, dict) and source_grants_full(item, now=clock):
            valid.append(item)

    providers: list[str] = []
    for item in valid:
        provider = normalize_billing_provider(item.get("provider"))
        if provider and provider not in providers:
            providers.append(provider)
    providers.sort()

    if not valid:
        return {
            "user_id": user_id,
            "access_level": "demo",
            "source": "default",
            "expires_at": None,
            "metadata": {"active_sources": []},
        }

    period_ends = [parse_timestamptz(item.get("current_period_end")) for item in valid]
    expires_at = None
    if all(end is not None for end in period_ends):
        expires_at = max(end for end in period_ends if end is not None)

    grant_source = "purchase"
    if not any(provider in PURCHASE_PROVIDERS for provider in providers):
        grant_source = "admin"

    metadata: dict[str, Any] = {"active_sources": providers}
    if "stripe" in providers:
        metadata["provider"] = "stripe"
    elif "google_play" in providers:
        metadata["provider"] = "google_play"
    elif providers:
        metadata["provider"] = providers[0]

    return {
        "user_id": user_id,
        "access_level": "full",
        "source": grant_source,
        "expires_at": expires_at.isoformat() if expires_at else None,
        "metadata": metadata,
    }
