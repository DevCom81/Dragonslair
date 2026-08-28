import unittest
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

import main


class PurchaseMeHttpTest(unittest.TestCase):
    def test_stripe_full_user_is_full_on_me(self) -> None:
        with patch(
            "main.get_user_id_from_access_token",
            new=AsyncMock(return_value="stripe-user"),
        ):
            with patch(
                "main.fetch_user_entitlement",
                new=AsyncMock(
                    return_value={
                        "user_id": "stripe-user",
                        "access_level": "full",
                        "source": "purchase",
                        "metadata": {"active_sources": ["stripe"]},
                    }
                ),
            ):
                client = TestClient(main.app)
                response = client.get(
                    "/v1/purchases/me",
                    headers={"Authorization": "Bearer stripe-jwt"},
                )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "access_level": "full",
                "entitlement": "full",
                "is_full": True,
                "source": "purchase",
                "active_sources": ["stripe"],
            },
        )

    def test_demo_user_stays_demo_on_me(self) -> None:
        with patch(
            "main.get_user_id_from_access_token",
            new=AsyncMock(return_value="demo-user"),
        ):
            with patch(
                "main.fetch_user_entitlement",
                new=AsyncMock(
                    return_value={
                        "user_id": "demo-user",
                        "access_level": "demo",
                        "source": "default",
                    }
                ),
            ):
                client = TestClient(main.app)
                response = client.get(
                    "/v1/purchases/me",
                    headers={"Authorization": "Bearer demo-jwt"},
                )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "access_level": "demo",
                "entitlement": "demo",
                "is_full": False,
                "source": "default",
            },
        )

    def test_double_provider_full_includes_active_sources(self) -> None:
        with patch(
            "main.get_user_id_from_access_token",
            new=AsyncMock(return_value="dual-user"),
        ):
            with patch(
                "main.fetch_user_entitlement",
                new=AsyncMock(
                    return_value={
                        "user_id": "dual-user",
                        "access_level": "full",
                        "source": "purchase",
                        "metadata": {
                            "active_sources": ["google_play", "stripe"],
                        },
                    }
                ),
            ):
                client = TestClient(main.app)
                response = client.get(
                    "/v1/purchases/me",
                    headers={"Authorization": "Bearer dual-jwt"},
                )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertTrue(body["is_full"])
        self.assertEqual(body["entitlement"], "full")
        self.assertEqual(body["active_sources"], ["google_play", "stripe"])

    def test_full_user_cannot_open_stripe_checkout(self) -> None:
        with patch(
            "main.get_user_id_from_access_token",
            new=AsyncMock(return_value="full-user"),
        ):
            with patch(
                "main.fetch_user_entitlement",
                new=AsyncMock(
                    return_value={
                        "user_id": "full-user",
                        "access_level": "full",
                        "source": "purchase",
                        "metadata": {"active_sources": ["google_play"]},
                    }
                ),
            ):
                with patch("main.create_stripe_checkout_url", new=AsyncMock()) as checkout:
                    client = TestClient(main.app)
                    response = client.post(
                        "/v1/purchases/checkout",
                        headers={"Authorization": "Bearer full-jwt"},
                    )
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json(), {"detail": "PURCHASE_ALREADY_FULL"})
        checkout.assert_not_awaited()

    def test_google_play_full_user_is_full_on_me(self) -> None:
        with patch(
            "main.get_user_id_from_access_token",
            new=AsyncMock(return_value="play-user"),
        ):
            with patch(
                "main.fetch_user_entitlement",
                new=AsyncMock(
                    return_value={
                        "user_id": "play-user",
                        "access_level": "full",
                        "source": "purchase",
                        "metadata": {"active_sources": ["google_play"]},
                    }
                ),
            ):
                client = TestClient(main.app)
                response = client.get(
                    "/v1/purchases/me",
                    headers={"Authorization": "Bearer play-jwt"},
                )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "access_level": "full",
                "entitlement": "full",
                "is_full": True,
                "source": "purchase",
                "active_sources": ["google_play"],
            },
        )


if __name__ == "__main__":
    unittest.main()
