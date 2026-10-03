export class ForbiddenError extends Error {
  constructor(message = "Forbidden") {
    super(message);
    this.name = "ForbiddenError";
  }
}

export class GameRuleError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "GameRuleError";
  }
}

export class NotFoundError extends Error {
  constructor(message = "Not found") {
    super(message);
    this.name = "NotFoundError";
  }
}

export const RATE_LIMITED = "RATE_LIMITED";
export const DEMO_EXPIRED = "DEMO_EXPIRED";
export const NOT_ENTITLED = "NOT_ENTITLED";

export class RateLimitedError extends Error {
  constructor() {
    super(RATE_LIMITED);
    this.name = "RateLimitedError";
  }
}

export class GameMasterBackendError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "GameMasterBackendError";
  }
}

export class RoomFinishedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RoomFinishedError";
  }
}
