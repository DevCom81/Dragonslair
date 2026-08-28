import hashlib
import hmac
import os
import time
from typing import Any

PURCHASE_SOURCES = {"purchase", "admin", "promo"}
PURCHASE_ALREADY_FULL = "PURCHASE_ALREADY_FULL"
CHECKOUT_COMPLETED_TYPES = {
    "checkout.session.completed",
    "checkout.session.async_payment_succeeded",
}
STRIPE_INACTIVE_TYPES = {"charge.refunded"}


class PurchaseConfigError(RuntimeError):
    pass


class PurchaseSignatureError(RuntimeError):
    pass


def stripe_secret_key() -> str:
    return os.getenv("STRIPE_SECRET_KEY", "").strip()


def stripe_webhook_secret() -> str:
    return os.getenv("STRIPE_WEBHOOK_SECRET", "").strip()


def stripe_price_id() -> str:
    return os.getenv("STRIPE_DRAGONSLAIR_PRICE_ID", "").strip()


def checkout_success_url() -> str:
    return os.getenv("CHECKOUT_SUCCESS_URL", "").strip()


def checkout_cancel_url() -> str:
    return os.getenv("CHECKOUT_CANCEL_URL", "").strip()


def is_checkout_configured() -> bool:
    return bool(stripe_secret_key() and stripe_price_id() and checkout_success_url())


def is_webhook_configured() -> bool:
    return bool(stripe_webhook_secret())


def already_has_full_access(entitlement: object) -> bool:
    from entitlements import entitlement_row_is_full

    return entitlement_row_is_full(entitlement)


def normalize_purchase_source(value: object) -> str:
    raw = str(value or "").strip().lower()
    if raw in PURCHASE_SOURCES:
        return raw
    return "purchase"


def user_id_from_checkout_session(session: dict[str, Any]) -> str | None:
    reference = session.get("client_reference_id")
    if isinstance(reference, str) and reference.strip():
        return reference.strip()
    metadata = session.get("metadata")
    if isinstance(metadata, dict):
        nested = metadata.get("user_id")
        if isinstance(nested, str) and nested.strip():
            return nested.strip()
    return None


def parse_checkout_user_id(event: dict[str, Any]) -> str | None:
    event_type = str(event.get("type") or "")
    if event_type not in CHECKOUT_COMPLETED_TYPES:
        return None
    data = event.get("data")
    if not isinstance(data, dict):
        return None
    session = data.get("object")
    if not isinstance(session, dict):
        return None
    status = str(session.get("payment_status") or "")
    if event_type == "checkout.session.completed" and status not in {
        "paid",
        "no_payment_required",
    }:
        return None
    return user_id_from_checkout_session(session)


def parse_stripe_inactive_user_id(event: dict[str, Any]) -> str | None:
    event_type = str(event.get("type") or "")
    if event_type not in STRIPE_INACTIVE_TYPES:
        return None
    data = event.get("data")
    if not isinstance(data, dict):
        return None
    charge = data.get("object")
    if not isinstance(charge, dict):
        return None
    if charge.get("refunded") is not True:
        return None
    return user_id_from_checkout_session(charge)


def session_id_from_event(event: dict[str, Any]) -> str:
    data = event.get("data")
    if not isinstance(data, dict):
        return ""
    session = data.get("object")
    if not isinstance(session, dict):
        return ""
    value = session.get("id")
    return str(value).strip() if value else ""


def offer_from_stripe_price(payload: dict[str, Any]) -> dict[str, Any]:
    unit_amount = payload.get("unit_amount")
    currency = str(payload.get("currency") or "").strip().lower()
    if not isinstance(unit_amount, int) or unit_amount < 0 or not currency:
        raise PurchaseConfigError("Stripe price is missing amount or currency.")
    return {
        "currency": currency,
        "unit_amount": unit_amount,
        "price_id": str(payload.get("id") or stripe_price_id()),
    }


def verify_stripe_signature(
    *,
    payload: bytes,
    header: str,
    secret: str,
    tolerance_seconds: int = 300,
    now: int | None = None,
) -> None:
    if not secret:
        raise PurchaseConfigError("STRIPE_WEBHOOK_SECRET is not configured.")
    if not header.strip():
        raise PurchaseSignatureError("Missing Stripe-Signature header.")
    items: dict[str, list[str]] = {}
    for part in header.split(","):
        key, _, value = part.strip().partition("=")
        if key and value:
            items.setdefault(key, []).append(value)
    timestamps = items.get("t") or []
    signatures = items.get("v1") or []
    if not timestamps or not signatures:
        raise PurchaseSignatureError("Invalid Stripe-Signature header.")
    try:
        timestamp = int(timestamps[0])
    except ValueError as error:
        raise PurchaseSignatureError("Invalid Stripe timestamp.") from error
    current = int(now if now is not None else time.time())
    if abs(current - timestamp) > tolerance_seconds:
        raise PurchaseSignatureError("Stripe signature timestamp is too old.")
    signed = f"{timestamp}.".encode("utf-8") + payload
    expected = hmac.new(secret.encode("utf-8"), signed, hashlib.sha256).hexdigest()
    if not any(hmac.compare_digest(expected, candidate) for candidate in signatures):
        raise PurchaseSignatureError("Stripe signature mismatch.")


def grant_metadata(*, session_id: str) -> dict[str, str]:
    data = {"provider": "stripe"}
    if session_id:
        data["stripe_session_id"] = session_id[:120]
    return data


async def fetch_stripe_offer() -> dict[str, Any]:
    import httpx

    if not is_checkout_configured():
        raise PurchaseConfigError("PURCHASE_UNAVAILABLE")
    price_id = stripe_price_id()
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.get(
            f"https://api.stripe.com/v1/prices/{price_id}",
            auth=(stripe_secret_key(), ""),
        )
    if response.status_code >= 400:
        raise PurchaseConfigError("Unable to load Stripe price.")
    payload = response.json()
    if not isinstance(payload, dict):
        raise PurchaseConfigError("Invalid Stripe price payload.")
    return offer_from_stripe_price(payload)


async def create_stripe_checkout_url(*, user_id: str) -> str:
    import httpx

    if not is_checkout_configured():
        raise PurchaseConfigError("PURCHASE_UNAVAILABLE")
    cancel = checkout_cancel_url() or checkout_success_url()
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post(
            "https://api.stripe.com/v1/checkout/sessions",
            auth=(stripe_secret_key(), ""),
            data={
                "mode": "payment",
                "client_reference_id": user_id,
                "metadata[user_id]": user_id,
                "payment_intent_data[metadata][user_id]": user_id,
                "line_items[0][price]": stripe_price_id(),
                "line_items[0][quantity]": "1",
                "success_url": checkout_success_url(),
                "cancel_url": cancel,
            },
        )
    if response.status_code >= 400:
        raise PurchaseConfigError("Unable to create Stripe Checkout session.")
    payload = response.json()
    url = payload.get("url") if isinstance(payload, dict) else None
    if not isinstance(url, str) or not url.startswith("https://"):
        raise PurchaseConfigError("Stripe Checkout did not return a URL.")
    return url
