/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as applyActions from "../applyActions.js";
import type * as combat from "../combat.js";
import type * as combatSessions from "../combatSessions.js";
import type * as demoSessions from "../demoSessions.js";
import type * as downloadAccess from "../downloadAccess.js";
import type * as downloads from "../downloads.js";
import type * as enemies from "../enemies.js";
import type * as entitlements from "../entitlements.js";
import type * as gameEvents from "../gameEvents.js";
import type * as gameMaster from "../gameMaster.js";
import type * as googlePlay from "../googlePlay.js";
import type * as http from "../http.js";
import type * as lib_access from "../lib/access.js";
import type * as lib_aiUsage from "../lib/aiUsage.js";
import type * as lib_auth from "../lib/auth.js";
import type * as lib_campaignMemory from "../lib/campaignMemory.js";
import type * as lib_demoClock from "../lib/demoClock.js";
import type * as lib_entitlements from "../lib/entitlements.js";
import type * as lib_errors from "../lib/errors.js";
import type * as lib_finishRoom from "../lib/finishRoom.js";
import type * as lib_gmLocale from "../lib/gmLocale.js";
import type * as lib_gmValidate from "../lib/gmValidate.js";
import type * as lib_googleOidc from "../lib/googleOidc.js";
import type * as lib_googlePlayPublisher from "../lib/googlePlayPublisher.js";
import type * as lib_googlePlayPurchase from "../lib/googlePlayPurchase.js";
import type * as lib_googlePlayRtdn from "../lib/googlePlayRtdn.js";
import type * as lib_openRouter from "../lib/openRouter.js";
import type * as lib_playAccountId from "../lib/playAccountId.js";
import type * as lib_rateLimit from "../lib/rateLimit.js";
import type * as lib_stateEffects from "../lib/stateEffects.js";
import type * as lib_stripeEvents from "../lib/stripeEvents.js";
import type * as lib_stripeWebhook from "../lib/stripeWebhook.js";
import type * as lib_validators from "../lib/validators.js";
import type * as lib_windowsDownload from "../lib/windowsDownload.js";
import type * as migrationAudit from "../migrationAudit.js";
import type * as migrationImport from "../migrationImport.js";
import type * as pendingRolls from "../pendingRolls.js";
import type * as players from "../players.js";
import type * as profiles from "../profiles.js";
import type * as prompts from "../prompts.js";
import type * as rolls from "../rolls.js";
import type * as rooms from "../rooms.js";
import type * as spike from "../spike.js";
import type * as spikeAuth from "../spikeAuth.js";
import type * as stripe from "../stripe.js";
import type * as users from "../users.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  applyActions: typeof applyActions;
  combat: typeof combat;
  combatSessions: typeof combatSessions;
  demoSessions: typeof demoSessions;
  downloadAccess: typeof downloadAccess;
  downloads: typeof downloads;
  enemies: typeof enemies;
  entitlements: typeof entitlements;
  gameEvents: typeof gameEvents;
  gameMaster: typeof gameMaster;
  googlePlay: typeof googlePlay;
  http: typeof http;
  "lib/access": typeof lib_access;
  "lib/aiUsage": typeof lib_aiUsage;
  "lib/auth": typeof lib_auth;
  "lib/campaignMemory": typeof lib_campaignMemory;
  "lib/demoClock": typeof lib_demoClock;
  "lib/entitlements": typeof lib_entitlements;
  "lib/errors": typeof lib_errors;
  "lib/finishRoom": typeof lib_finishRoom;
  "lib/gmLocale": typeof lib_gmLocale;
  "lib/gmValidate": typeof lib_gmValidate;
  "lib/googleOidc": typeof lib_googleOidc;
  "lib/googlePlayPublisher": typeof lib_googlePlayPublisher;
  "lib/googlePlayPurchase": typeof lib_googlePlayPurchase;
  "lib/googlePlayRtdn": typeof lib_googlePlayRtdn;
  "lib/openRouter": typeof lib_openRouter;
  "lib/playAccountId": typeof lib_playAccountId;
  "lib/rateLimit": typeof lib_rateLimit;
  "lib/stateEffects": typeof lib_stateEffects;
  "lib/stripeEvents": typeof lib_stripeEvents;
  "lib/stripeWebhook": typeof lib_stripeWebhook;
  "lib/validators": typeof lib_validators;
  "lib/windowsDownload": typeof lib_windowsDownload;
  migrationAudit: typeof migrationAudit;
  migrationImport: typeof migrationImport;
  pendingRolls: typeof pendingRolls;
  players: typeof players;
  profiles: typeof profiles;
  prompts: typeof prompts;
  rolls: typeof rolls;
  rooms: typeof rooms;
  spike: typeof spike;
  spikeAuth: typeof spikeAuth;
  stripe: typeof stripe;
  users: typeof users;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
