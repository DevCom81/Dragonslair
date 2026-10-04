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

export class MigrationCollisionError extends Error {
  constructor(message = "Migration collision") {
    super(message);
    this.name = "MigrationCollisionError";
  }
}

export const RATE_LIMITED = "RATE_LIMITED";
export const DEMO_EXPIRED = "DEMO_EXPIRED";
export const NOT_ENTITLED = "NOT_ENTITLED";
export const FULL_GAME_REQUIRED = "FULL_GAME_REQUIRED";
export const WINDOWS_DOWNLOAD_UNAVAILABLE = "WINDOWS_DOWNLOAD_UNAVAILABLE";
export const PURCHASE_ALREADY_FULL = "PURCHASE_ALREADY_FULL";
export const PURCHASE_UNAVAILABLE = "PURCHASE_UNAVAILABLE";
export const PURCHASE_PENDING = "PURCHASE_PENDING";
export const GOOGLE_PLAY_UNAVAILABLE = "GOOGLE_PLAY_UNAVAILABLE";
export const GOOGLE_PLAY_ACCOUNT_MISMATCH = "GOOGLE_PLAY_ACCOUNT_MISMATCH";
export const GOOGLE_PLAY_PACKAGE_MISMATCH = "GOOGLE_PLAY_PACKAGE_MISMATCH";
export const GOOGLE_PLAY_PRODUCT_MISMATCH = "GOOGLE_PLAY_PRODUCT_MISMATCH";
export const GOOGLE_PLAY_PURCHASE_INVALID = "GOOGLE_PLAY_PURCHASE_INVALID";
export const GOOGLE_PLAY_RTDN_UNAUTHORIZED = "GOOGLE_PLAY_RTDN_UNAUTHORIZED";
export const GOOGLE_PLAY_RTDN_INVALID = "GOOGLE_PLAY_RTDN_INVALID";
export const GOOGLE_PLAY_RTDN_UNAVAILABLE = "GOOGLE_PLAY_RTDN_UNAVAILABLE";

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

export class PurchaseUnavailableError extends Error {
  constructor(message = PURCHASE_UNAVAILABLE) {
    super(message);
    this.name = "PurchaseUnavailableError";
  }
}

export class PurchaseSignatureError extends Error {
  constructor(message = "Invalid Stripe signature.") {
    super(message);
    this.name = "PurchaseSignatureError";
  }
}

export class GooglePlayConfigError extends Error {
  constructor(message = GOOGLE_PLAY_UNAVAILABLE) {
    super(message);
    this.name = "GooglePlayConfigError";
  }
}

export class GooglePlayPurchaseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "GooglePlayPurchaseError";
  }
}

export class GooglePlayPendingError extends Error {
  constructor(message = PURCHASE_PENDING) {
    super(message);
    this.name = "GooglePlayPendingError";
  }
}

export class GooglePlayRtdnUnauthorizedError extends Error {
  constructor(message = GOOGLE_PLAY_RTDN_UNAUTHORIZED) {
    super(message);
    this.name = "GooglePlayRtdnUnauthorizedError";
  }
}

export class GooglePlayRtdnError extends Error {
  constructor(message = GOOGLE_PLAY_RTDN_INVALID) {
    super(message);
    this.name = "GooglePlayRtdnError";
  }
}

export class DownloadConfigError extends Error {
  constructor(message = WINDOWS_DOWNLOAD_UNAVAILABLE) {
    super(message);
    this.name = "DownloadConfigError";
  }
}
