from typing import Any

HIDDEN_WORLD_KEYS = {"gm_secrets", "gm_state", "secrets", "secret"}


def public_world_state(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        return {}
    return {
        key: item
        for key, item in value.items()
        if key not in HIDDEN_WORLD_KEYS
    }
