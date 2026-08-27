from typing import Any, Literal

from pydantic import BaseModel, Field


GameMasterActionType = Literal[
    "narrate",
    "spawn_enemy",
    "move_enemy",
    "damage_player",
    "heal_player",
    "give_item",
    "remove_item",
    "start_combat",
    "end_combat",
    "system_message",
    "request_roll",
    "apply_effect",
    "remove_effect",
]


class BoardPosition(BaseModel):
    x: float = Field(ge=0, le=1)
    y: float = Field(ge=0, le=1)


class GamePlayer(BaseModel):
    id: str
    name: str
    hp: int = Field(ge=0)
    figurine_id: int = Field(ge=0, le=39)
    position: BoardPosition | None = None
    inventory: list[dict[str, Any]] = Field(default_factory=list)
    strength: int = Field(default=10, ge=1, le=30)
    dexterity: int = Field(default=10, ge=1, le=30)
    constitution: int = Field(default=10, ge=1, le=30)
    intelligence: int = Field(default=10, ge=1, le=30)
    wisdom: int = Field(default=10, ge=1, le=30)
    charisma: int = Field(default=10, ge=1, le=30)
    effects: list[dict[str, Any]] = Field(default_factory=list)


class RecentGameEvent(BaseModel):
    type: Literal["action", "narration", "system"]
    content: str = Field(min_length=1, max_length=2000)


class GameMasterRequest(BaseModel):
    room_id: str = Field(min_length=1)
    player_id: str = Field(min_length=1)
    player_name: str = Field(default="Aventurier", min_length=1, max_length=80)
    action: str = Field(min_length=1, max_length=1200)
    players: list[GamePlayer] = Field(default_factory=list)
    recent_events: list[RecentGameEvent] = Field(default_factory=list, max_length=20)


class GameMasterAction(BaseModel):
    type: GameMasterActionType
    payload: dict[str, Any] = Field(default_factory=dict)


class GameMasterChoice(BaseModel):
    label: str = Field(min_length=1, max_length=160)
    action: str | None = Field(default=None, max_length=240)


class GameMasterResponse(BaseModel):
    narration: str = Field(min_length=1, max_length=4000)
    actions: list[GameMasterAction] = Field(default_factory=list, max_length=12)
    choices: list[GameMasterChoice] = Field(default_factory=list, max_length=6)
