import os
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi.testclient import TestClient

import main
from downloads import (
    DOWNLOAD_EXPIRES_SECONDS,
    WINDOWS_DOWNLOAD_FILENAME,
    create_windows_presigned_url,
    is_windows_download_configured,
)


_R2_ENV = {
    "R2_ACCESS_KEY_ID": "test-access-key",
    "R2_SECRET_ACCESS_KEY": "test-secret-key",
    "R2_ENDPOINT": "https://example.r2.cloudflarestorage.com",
    "R2_BUCKET": "dragonslair-release",
    "R2_WINDOWS_OBJECT": "windows/Install_Dragonslair.exe",
}


class WindowsDownloadTest(unittest.TestCase):
    def test_not_configured_without_env(self) -> None:
        empty = {key: "" for key in _R2_ENV}
        with patch.dict(os.environ, empty):
            self.assertFalse(is_windows_download_configured())

    def test_presigned_url_uses_get_expiry_and_filename(self) -> None:
        client = MagicMock()
        client.generate_presigned_url.return_value = "https://signed.example/file"

        with patch.dict(os.environ, _R2_ENV):
            with patch("downloads._s3_client", return_value=client):
                url = create_windows_presigned_url(user_id="user-1")

        self.assertEqual(url, "https://signed.example/file")
        client.generate_presigned_url.assert_called_once()
        kwargs = client.generate_presigned_url.call_args.kwargs
        self.assertEqual(kwargs["ClientMethod"], "get_object")
        self.assertEqual(kwargs["ExpiresIn"], DOWNLOAD_EXPIRES_SECONDS)
        self.assertEqual(kwargs["ExpiresIn"], 300)
        params = kwargs["Params"]
        self.assertEqual(params["Bucket"], "dragonslair-release")
        self.assertEqual(params["Key"], "windows/Install_Dragonslair.exe")
        self.assertIn(WINDOWS_DOWNLOAD_FILENAME, params["ResponseContentDisposition"])
        self.assertIn("attachment", params["ResponseContentDisposition"])

    def test_endpoint_rejects_missing_jwt(self) -> None:
        client = TestClient(main.app)
        response = client.get("/v1/downloads/windows")
        self.assertEqual(response.status_code, 401)

    def test_endpoint_returns_download_url_for_authenticated_user(self) -> None:
        with patch(
            "main.get_user_id_from_access_token",
            new=AsyncMock(return_value="user-1"),
        ):
            with patch(
                "main.create_windows_presigned_url",
                return_value="https://signed.example/file",
            ) as presign:
                client = TestClient(main.app)
                response = client.get(
                    "/v1/downloads/windows",
                    headers={"Authorization": "Bearer test-token"},
                )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"download_url": "https://signed.example/file"})
        presign.assert_called_once()
        self.assertEqual(presign.call_args.kwargs["user_id"], "user-1")


if __name__ == "__main__":
    unittest.main()
