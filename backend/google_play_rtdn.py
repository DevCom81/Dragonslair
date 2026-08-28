import base64
import json
import logging
import os
from typing import Any

from google_play import (
    GooglePlayBillingService,
    GooglePlayConfigError,
    GooglePlayPurchaseError,
    google_play_package_name,
    google_play_product_id,
    is_google_play_configured,
    purchase_token_fingerprint,
)
from supabase_admin import (
    find_entitlement_user_by_google_play_ref,
    find_entitlement_user_by_play_account_id,
    SupabaseAdminError,
)

logger = logging.getLogger("dragons_lair")


class GooglePlayRtdnError(RuntimeError):
    pass


class GooglePlayRtdnUnauthorizedError(GooglePlayRtdnError):
    pass


def google_play_rtdn_audience() -> str:
    return os.getenv("GOOGLE_PLAY_RTDN_AUDIENCE", "").strip()


def is_rtdn_configured() -> bool:
    return is_google_play_configured() and bool(google_play_rtdn_audience())


def verify_pubsub_push_jwt(authorization: str | None) -> None:
    audience = google_play_rtdn_audience()
    if not audience:
        raise GooglePlayConfigError("GOOGLE_PLAY_RTDN_UNAVAILABLE")
    header = str(authorization or "").strip()
    if not header.startswith("Bearer "):
        raise GooglePlayRtdnUnauthorizedError("GOOGLE_PLAY_RTDN_UNAUTHORIZED")
    token = header[7:].strip()
    if not token:
        raise GooglePlayRtdnUnauthorizedError("GOOGLE_PLAY_RTDN_UNAUTHORIZED")
    from google.auth.transport import requests as google_requests
    from google.oauth2 import id_token

    id_token.verify_oauth2_token(token, google_requests.Request(), audience=audience)


def decode_pubsub_push(body: object) -> dict[str, Any]:
    if not isinstance(body, dict):
        raise GooglePlayRtdnError("GOOGLE_PLAY_RTDN_INVALID")
    message = body.get("message")
    if not isinstance(message, dict):
        raise GooglePlayRtdnError("GOOGLE_PLAY_RTDN_INVALID")
    raw_data = message.get("data")
    if not isinstance(raw_data, str) or not raw_data.strip():
        raise GooglePlayRtdnError("GOOGLE_PLAY_RTDN_INVALID")
    try:
        decoded = base64.b64decode(raw_data, validate=True)
        payload = json.loads(decoded.decode("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError, ValueError) as error:
        raise GooglePlayRtdnError("GOOGLE_PLAY_RTDN_INVALID") from error
    if not isinstance(payload, dict):
        raise GooglePlayRtdnError("GOOGLE_PLAY_RTDN_INVALID")
    return {
        "payload": payload,
        "message_id": str(message.get("messageId") or "").strip(),
    }


def parse_developer_notification(payload: object) -> dict[str, Any] | None:
    if not isinstance(payload, dict):
        return None
    if isinstance(payload.get("testNotification"), dict):
        return {"kind": "test"}
    if isinstance(payload.get("subscriptionNotification"), dict):
        return {"kind": "ignored_subscription"}
    package_name = str(payload.get("packageName") or "").strip()
    product = payload.get("oneTimeProductNotification")
    if isinstance(product, dict):
        purchase_token = str(product.get("purchaseToken") or "").strip()
        product_id = str(product.get("sku") or "").strip()
        notification_type = product.get("notificationType")
        if not purchase_token or not product_id:
            return None
        return {
            "kind": "product",
            "package_name": package_name,
            "product_id": product_id,
            "purchase_token": purchase_token,
            "notification_type": notification_type,
        }
    return None


async def resolve_google_play_user_id(
    *,
    purchase_token: str,
    product_id: str,
    billing: GooglePlayBillingService | None = None,
) -> str | None:
    user_id = await find_entitlement_user_by_google_play_ref(
        purchase_token_fingerprint(purchase_token),
    )
    if user_id:
        return user_id
    service = billing or GooglePlayBillingService()
    try:
        record = await service.inspect(
            product_id=product_id,
            purchase_token=purchase_token,
        )
    except (GooglePlayPurchaseError, GooglePlayConfigError):
        return None
    account_id = str(record.payload.get("obfuscatedExternalAccountId") or "").strip()
    if not account_id:
        return None
    return await find_entitlement_user_by_play_account_id(account_id)


async def process_rtdn_notification(body: object) -> dict[str, str]:
    if not is_rtdn_configured():
        raise GooglePlayConfigError("GOOGLE_PLAY_RTDN_UNAVAILABLE")
    envelope = decode_pubsub_push(body)
    parsed = parse_developer_notification(envelope["payload"])
    if parsed is None:
        return {"status": "ignored", "reason": "unknown_notification"}
    if parsed.get("kind") == "test":
        return {"status": "ignored", "reason": "test"}
    if parsed.get("kind") == "ignored_subscription":
        return {"status": "ignored", "reason": "subscription_not_supported"}
    expected_package = google_play_package_name()
    package_name = str(parsed.get("package_name") or "").strip()
    if package_name and package_name != expected_package:
        return {"status": "ignored", "reason": "package_mismatch"}
    expected_product = google_play_product_id()
    product_id = str(parsed.get("product_id") or "").strip()
    if not expected_product or product_id != expected_product:
        return {"status": "ignored", "reason": "product_mismatch"}
    purchase_token = str(parsed.get("purchase_token") or "").strip()
    if not purchase_token:
        return {"status": "ignored", "reason": "missing_token"}
    billing = GooglePlayBillingService()
    user_id = await resolve_google_play_user_id(
        purchase_token=purchase_token,
        product_id=product_id,
        billing=billing,
    )
    if user_id is None:
        logger.warning(
            "google play rtdn ignored: user not linked message_id=%s type=%s",
            envelope.get("message_id"),
            parsed.get("notification_type"),
        )
        return {"status": "ignored", "reason": "user_not_linked"}
    try:
        row = await billing.sync_entitlement(
            user_id=user_id,
            product_id=product_id,
            purchase_token=purchase_token,
        )
    except SupabaseAdminError as error:
        raise GooglePlayRtdnError(str(error)) from error
    except (GooglePlayPurchaseError, GooglePlayConfigError) as error:
        logger.warning(
            "google play rtdn sync failed user_id=%s reason=%s",
            user_id,
            error,
        )
        return {"status": "ignored", "reason": str(error)}
    access_level = str(row.get("access_level") or "demo")
    return {"status": "ok", "access_level": access_level}
