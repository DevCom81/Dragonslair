import hashlib
import json
import logging
import os
from dataclasses import dataclass
from typing import Any, Awaitable, Callable, Literal
from urllib.parse import quote

import httpx

from supabase_admin import refresh_user_entitlement, upsert_entitlement_source
from entitlements import source_grants_full

logger = logging.getLogger("dragons_lair")

ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"

PurchaseLookup = Callable[[str, str, str], Awaitable[dict[str, Any]]]
GooglePlayStatus = Literal["purchased", "pending", "invalid"]
AcknowledgeFn = Callable[..., Awaitable[None]]


class GooglePlayConfigError(RuntimeError):
    pass


class GooglePlayPurchaseError(RuntimeError):
    pass


class GooglePlayPendingError(RuntimeError):
    pass


@dataclass(frozen=True)
class PlayVerifiedPurchase:
    source_status: str
    payload: dict[str, Any]

    @property
    def grants_full(self) -> bool:
        return source_grants_full(
            {
                "provider": "google_play",
                "status": self.source_status,
                "current_period_end": None,
            }
        )


def google_play_package_name() -> str:
    return os.getenv("GOOGLE_PLAY_PACKAGE_NAME", "").strip()


def google_play_product_id() -> str:
    return os.getenv("GOOGLE_PLAY_PRODUCT_ID", "").strip()


def is_google_play_configured() -> bool:
    return bool(
        google_play_package_name()
        and google_play_product_id()
        and os.getenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "").strip()
    )


def purchase_token_fingerprint(purchase_token: str) -> str:
    return hashlib.sha256(purchase_token.encode("utf-8")).hexdigest()


def play_obfuscated_account_id(user_id: str) -> str:
    trimmed = user_id.strip()
    if not trimmed:
        return ""
    return hashlib.sha256(f"dragons_lair:{trimmed}".encode("utf-8")).hexdigest()


def assert_play_account_binding(payload: object, user_id: str) -> None:
    expected = play_obfuscated_account_id(user_id)
    if not expected or not isinstance(payload, dict):
        raise GooglePlayPurchaseError("GOOGLE_PLAY_ACCOUNT_MISMATCH")
    actual = str(payload.get("obfuscatedExternalAccountId") or "").strip()
    if actual != expected:
        raise GooglePlayPurchaseError("GOOGLE_PLAY_ACCOUNT_MISMATCH")


def assert_play_package(payload: object) -> None:
    if not isinstance(payload, dict):
        return
    actual = str(payload.get("packageName") or "").strip()
    expected = google_play_package_name()
    if actual and actual != expected:
        raise GooglePlayPurchaseError("GOOGLE_PLAY_PACKAGE_MISMATCH")


def assert_play_product(payload: object, product_id: str) -> None:
    if not isinstance(payload, dict):
        return
    actual = str(payload.get("productId") or "").strip()
    if actual and actual != product_id:
        raise GooglePlayPurchaseError("GOOGLE_PLAY_PRODUCT_MISMATCH")


def interpret_product_lifecycle(payload: object) -> str | None:
    if not isinstance(payload, dict):
        return None
    state = payload.get("purchaseState")
    if state == 2:
        return "pending"
    if state == 0:
        return "active"
    if state == 1:
        return "revoked"
    return None


def interpret_product_purchase(payload: object) -> GooglePlayStatus:
    status = interpret_product_lifecycle(payload)
    if status == "pending":
        return "pending"
    if status == "active":
        return "purchased"
    return "invalid"


def needs_play_acknowledgement(payload: object) -> bool:
    if not isinstance(payload, dict):
        return False
    return payload.get("acknowledgementState") != 1


def _service_account_info() -> dict[str, Any]:
    raw = os.getenv("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "").strip()
    if not raw:
        raise GooglePlayConfigError("GOOGLE_PLAY_UNAVAILABLE")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as error:
        raise GooglePlayConfigError("GOOGLE_PLAY_UNAVAILABLE") from error
    if not isinstance(data, dict) or not str(data.get("private_key") or "").strip():
        raise GooglePlayConfigError("GOOGLE_PLAY_UNAVAILABLE")
    return data


def _google_access_token() -> str:
    from google.auth.transport.requests import Request
    from google.oauth2 import service_account

    credentials = service_account.Credentials.from_service_account_info(
        _service_account_info(),
        scopes=[ANDROID_PUBLISHER_SCOPE],
    )
    credentials.refresh(Request())
    token = credentials.token
    if not isinstance(token, str) or not token:
        raise GooglePlayConfigError("GOOGLE_PLAY_UNAVAILABLE")
    return token


async def _publisher_get(url: str) -> dict[str, Any]:
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.get(
            url,
            headers={"Authorization": f"Bearer {_google_access_token()}"},
        )
    if response.status_code in {400, 404}:
        raise GooglePlayPurchaseError("GOOGLE_PLAY_PURCHASE_INVALID")
    if response.status_code >= 400:
        logger.warning("google play lookup failed status=%s", response.status_code)
        raise GooglePlayConfigError("GOOGLE_PLAY_UNAVAILABLE")
    payload = response.json()
    if not isinstance(payload, dict):
        raise GooglePlayPurchaseError("GOOGLE_PLAY_PURCHASE_INVALID")
    return payload


async def _publisher_post(url: str) -> int:
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post(
            url,
            headers={
                "Authorization": f"Bearer {_google_access_token()}",
                "Content-Type": "application/json",
            },
            json={},
        )
    return response.status_code


async def fetch_google_product_purchase(
    *,
    package_name: str,
    product_id: str,
    purchase_token: str,
) -> dict[str, Any]:
    url = (
        "https://androidpublisher.googleapis.com/androidpublisher/v3/"
        f"applications/{quote(package_name, safe='.-_')}/purchases/products/"
        f"{quote(product_id, safe='.-_')}/tokens/"
        f"{quote(purchase_token, safe='')}"
    )
    return await _publisher_get(url)


async def acknowledge_play_purchase(
    *,
    product_id: str,
    purchase_token: str,
) -> None:
    package_name = google_play_package_name()
    url = (
        "https://androidpublisher.googleapis.com/androidpublisher/v3/"
        f"applications/{quote(package_name, safe='.-_')}/purchases/products/"
        f"{quote(product_id, safe='.-_')}/tokens/"
        f"{quote(purchase_token, safe='')}:acknowledge"
    )
    status = await _publisher_post(url)
    if status in {204, 400}:
        return
    logger.warning("google play acknowledge failed status=%s", status)
    raise GooglePlayConfigError("GOOGLE_PLAY_UNAVAILABLE")


class GooglePlayBillingService:
    """Google Play Developer API — one-time non-consumable products only."""

    async def inspect(
        self,
        *,
        product_id: str,
        purchase_token: str,
        fetch_purchase: PurchaseLookup | None = None,
    ) -> PlayVerifiedPurchase:
        if not is_google_play_configured():
            raise GooglePlayConfigError("GOOGLE_PLAY_UNAVAILABLE")
        package_name = google_play_package_name()
        if fetch_purchase is None:
            payload = await fetch_google_product_purchase(
                package_name=package_name,
                product_id=product_id,
                purchase_token=purchase_token,
            )
        else:
            payload = await fetch_purchase(package_name, product_id, purchase_token)
        if not isinstance(payload, dict):
            raise GooglePlayPurchaseError("GOOGLE_PLAY_PURCHASE_INVALID")
        assert_play_package(payload)
        assert_play_product(payload, product_id)
        source_status = interpret_product_lifecycle(payload)
        if not source_status:
            raise GooglePlayPurchaseError("GOOGLE_PLAY_PURCHASE_INVALID")
        return PlayVerifiedPurchase(source_status=source_status, payload=payload)

    async def redeem(
        self,
        *,
        user_id: str,
        product_id: str,
        purchase_token: str,
        fetch_purchase: PurchaseLookup | None = None,
        acknowledge: AcknowledgeFn | None = None,
    ) -> dict:
        expected = google_play_product_id()
        if not expected or product_id != expected:
            raise GooglePlayPurchaseError("GOOGLE_PLAY_PRODUCT_MISMATCH")
        token = purchase_token.strip()
        if not token or len(token) > 4096:
            raise GooglePlayPurchaseError("GOOGLE_PLAY_PURCHASE_INVALID")
        record = await self.inspect(
            product_id=product_id,
            purchase_token=token,
            fetch_purchase=fetch_purchase,
        )
        if record.source_status == "pending":
            raise GooglePlayPendingError("PURCHASE_PENDING")
        assert_play_account_binding(record.payload, user_id)
        if record.grants_full and needs_play_acknowledgement(record.payload):
            ack = acknowledge or acknowledge_play_purchase
            await ack(product_id=product_id, purchase_token=token)
        logger.info(
            "google play purchase verified user_id=%s product=%s status=%s",
            user_id,
            product_id,
            record.source_status,
        )
        await upsert_entitlement_source(
            user_id=user_id,
            provider="google_play",
            provider_ref=purchase_token_fingerprint(token),
            status=record.source_status,
            current_period_end=None,
            metadata={
                "provider": "google_play",
                "play_account_id": play_obfuscated_account_id(user_id),
            },
        )
        return await refresh_user_entitlement(user_id=user_id)

    async def sync_entitlement(
        self,
        *,
        user_id: str,
        product_id: str,
        purchase_token: str,
        fetch_purchase: PurchaseLookup | None = None,
        acknowledge: AcknowledgeFn | None = None,
    ) -> dict:
        """RTDN / server-side refresh. Never raises for pending or non-granting states."""
        expected = google_play_product_id()
        if not expected or product_id != expected:
            raise GooglePlayPurchaseError("GOOGLE_PLAY_PRODUCT_MISMATCH")
        token = purchase_token.strip()
        if not token or len(token) > 4096:
            raise GooglePlayPurchaseError("GOOGLE_PLAY_PURCHASE_INVALID")
        record = await self.inspect(
            product_id=product_id,
            purchase_token=token,
            fetch_purchase=fetch_purchase,
        )
        if record.grants_full and needs_play_acknowledgement(record.payload):
            ack = acknowledge or acknowledge_play_purchase
            await ack(product_id=product_id, purchase_token=token)
        logger.info(
            "google play entitlement synced user_id=%s product=%s status=%s",
            user_id,
            product_id,
            record.source_status,
        )
        await upsert_entitlement_source(
            user_id=user_id,
            provider="google_play",
            provider_ref=purchase_token_fingerprint(token),
            status=record.source_status,
            current_period_end=None,
            metadata={
                "provider": "google_play",
                "play_account_id": play_obfuscated_account_id(user_id),
            },
        )
        return await refresh_user_entitlement(user_id=user_id)


async def redeem_google_play_purchase(
    *,
    user_id: str,
    product_id: str,
    purchase_token: str,
    fetch_purchase: PurchaseLookup | None = None,
    acknowledge: AcknowledgeFn | None = None,
) -> dict:
    return await GooglePlayBillingService().redeem(
        user_id=user_id,
        product_id=product_id,
        purchase_token=purchase_token,
        fetch_purchase=fetch_purchase,
        acknowledge=acknowledge,
    )
