from typing import Any, Literal

from pydantic import BaseModel, Field


GameMasterActionType = Literal[
    "narrate",
    "spawn_enemy",
    "move_enemy",
    "damage_enemy",
    "heal_enemy",
    "defeat_enemy",
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


class GameEnemy(BaseModel):
    id: str
    name: str
    enemy_type: str = "enemy"
    hp: int = Field(ge=0)
    max_hp: int = Field(ge=1)
    status: Literal["active", "defeated", "escaped"] = "active"
    position: BoardPosition | None = None


class SpawnEnemyPayload(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    enemy_type: str = Field(default="enemy", min_length=1, max_length=40)
    x: float = Field(default=0.5, ge=0, le=1)
    y: float = Field(default=0.5, ge=0, le=1)
    hp: int = Field(default=20, ge=1, le=500)
    max_hp: int | None = Field(default=None, ge=1, le=500)


class MoveEnemyPayload(BaseModel):
    enemy_id: str | None = Field(default=None, min_length=1)
    name: str | None = Field(default=None, min_length=1, max_length=80)
    x: float = Field(ge=0, le=1)
    y: float = Field(ge=0, le=1)


class EnemyHpPayload(BaseModel):
    enemy_id: str | None = Field(default=None, min_length=1)
    name: str | None = Field(default=None, min_length=1, max_length=80)
    amount: int = Field(ge=0, le=500)


class DefeatEnemyPayload(BaseModel):
    enemy_id: str | None = Field(default=None, min_length=1)
    name: str | None = Field(default=None, min_length=1, max_length=80)


class StartCombatPayload(BaseModel):
    round: int | None = Field(default=None, ge=1, le=999)


class CombatContext(BaseModel):
    active: bool = False
    round: int = Field(default=0, ge=0, le=999)


class RecentGameEvent(BaseModel):
    type: Literal["action", "narration", "system"]
    content: str = Field(min_length=1, max_length=2000)


class RollResult(BaseModel):
    pending_roll_id: str = Field(min_length=1)
    player_id: str = Field(min_length=1)
    ability: str = Field(min_length=1)
    dc: int = Field(ge=5, le=25)
    raw: int = Field(ge=1, le=20)
    modifier: int = Field(ge=-10, le=20)
    total: int
    success: bool
    reason: str = ""


class GameMasterRequest(BaseModel):
    room_id: str = Field(min_length=1)
    player_id: str = Field(min_length=1)
    player_name: str = Field(default="Aventurier", min_length=1, max_length=80)
    action: str = Field(min_length=1, max_length=1200)
    players: list[GamePlayer] = Field(default_factory=list)
    enemies: list[GameEnemy] = Field(default_factory=list)
    recent_events: list[RecentGameEvent] = Field(default_factory=list, max_length=20)
    combat: CombatContext | None = None
    world_state: dict[str, Any] = Field(default_factory=dict)
    gm_secrets: list[str] = Field(default_factory=list, max_length=12)
    roll_result: RollResult | None = None


class ResolveRollRequest(BaseModel):
    pending_roll_id: str = Field(min_length=1)
    raw: int = Field(ge=1, le=20)
    player_name: str = Field(default="Aventurier", min_length=1, max_length=80)
    players: list[GamePlayer] = Field(default_factory=list)
    enemies: list[GameEnemy] = Field(default_factory=list)
    recent_events: list[RecentGameEvent] = Field(default_factory=list, max_length=20)
    combat: CombatContext | None = None


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


SCENARIO_ORIENTATIONS = {
    "combat",
    "exploration",
    "investigation",
    "roleplay",
    "survival",
}
SCENARIO_DIFFICULTIES = {"easy", "standard", "hard"}
SCENARIO_DURATIONS = {"short", "medium", "long"}


class StartingLocation(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    description: str = Field(default="", max_length=400)


class ScenarioNpc(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    role: str = Field(default="", max_length=120)


class ScenarioThreat(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    hint: str = Field(default="", max_length=200)


class GenerateScenarioRequest(BaseModel):
    room_id: str = Field(min_length=1)
    prompt: str = Field(min_length=20, max_length=2000)
    title: str = Field(default="", max_length=80)
    tone: str = Field(default="", max_length=80)
    difficulty: str = Field(default="standard")
    duration: str = Field(default="medium")
    orientations: list[str] = Field(default_factory=list, max_length=5)
    improvise: bool = True
    permadeath: bool = False
    pvp: bool = False
    betrayals: bool = False


class GeneratedScenario(BaseModel):
    title: str = Field(min_length=1, max_length=80)
    setting: str = Field(min_length=1, max_length=800)
    tone: str = Field(default="", max_length=80)
    public_objective: str = Field(min_length=1, max_length=400)
    starting_location: StartingLocation
    initial_situation: str = Field(default="", max_length=800)
    known_facts: list[str] = Field(default_factory=list, max_length=12)
    starting_npcs: list[ScenarioNpc] = Field(default_factory=list, max_length=8)
    initial_threats: list[ScenarioThreat] = Field(default_factory=list, max_length=8)
    opening_narration: str = Field(min_length=1, max_length=2000)
    gm_secrets: list[str] = Field(default_factory=list, max_length=12)

    def public_dict(self) -> dict[str, Any]:
        data = self.model_dump()
        data.pop("gm_secrets", None)
        return data


class PublicScenarioResponse(BaseModel):
    world_state: dict[str, Any]
    opening_narration: str
