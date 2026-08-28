import logging
import os

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

logger = logging.getLogger("dragons_lair")

DOWNLOAD_EXPIRES_SECONDS = 300
WINDOWS_DOWNLOAD_FILENAME = "Install_Dragonslair.exe"


class DownloadConfigError(RuntimeError):
    pass


def _access_key_id() -> str:
    return os.getenv("R2_ACCESS_KEY_ID", "").strip()


def _secret_access_key() -> str:
    return os.getenv("R2_SECRET_ACCESS_KEY", "").strip()


def _endpoint() -> str:
    return os.getenv("R2_ENDPOINT", "").strip().rstrip("/")


def _bucket() -> str:
    return os.getenv("R2_BUCKET", "").strip()


def _windows_object() -> str:
    return os.getenv("R2_WINDOWS_OBJECT", "").strip()


def is_windows_download_configured() -> bool:
    return bool(
        _access_key_id()
        and _secret_access_key()
        and _endpoint()
        and _bucket()
        and _windows_object()
    )


def _s3_client():
    return boto3.client(
        "s3",
        endpoint_url=_endpoint(),
        aws_access_key_id=_access_key_id(),
        aws_secret_access_key=_secret_access_key(),
        region_name="auto",
        config=Config(
            signature_version="s3v4",
            s3={"addressing_style": "path"},
        ),
    )


def create_windows_presigned_url(*, user_id: str) -> str:
    if not is_windows_download_configured():
        raise DownloadConfigError("WINDOWS_DOWNLOAD_UNAVAILABLE")

    bucket = _bucket()
    object_key = _windows_object()
    try:
        url = _s3_client().generate_presigned_url(
            ClientMethod="get_object",
            Params={
                "Bucket": bucket,
                "Key": object_key,
                "ResponseContentDisposition": (
                    f'attachment; filename="{WINDOWS_DOWNLOAD_FILENAME}"'
                ),
            },
            ExpiresIn=DOWNLOAD_EXPIRES_SECONDS,
        )
    except (BotoCoreError, ClientError) as error:
        logger.warning("windows download presign failed user_id=%s", user_id)
        raise DownloadConfigError("WINDOWS_DOWNLOAD_UNAVAILABLE") from error

    logger.info(
        "windows download issued user_id=%s object=%s expires_in=%s",
        user_id,
        object_key,
        DOWNLOAD_EXPIRES_SECONDS,
    )
    return url
