import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";
import {
  GOOGLE_PLAY_RTDN_INVALID,
  GOOGLE_PLAY_RTDN_UNAUTHORIZED,
  GOOGLE_PLAY_RTDN_UNAVAILABLE,
  GOOGLE_PLAY_UNAVAILABLE,
  PURCHASE_UNAVAILABLE,
} from "./lib/errors";

const http = httpRouter();

http.route({
  path: "/stripe-webhook",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const signature = request.headers.get("stripe-signature") ?? "";
    const payload = await request.text();
    try {
      const result = await ctx.runAction(internal.stripe.processWebhook, {
        payload,
        signature,
      });
      return new Response(JSON.stringify(result), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } catch (error) {
      const name =
        error !== null &&
        typeof error === "object" &&
        "name" in error &&
        typeof error.name === "string"
          ? error.name
          : "";
      const message = error instanceof Error ? error.message : "";
      if (
        name === "PurchaseSignatureError" ||
        message === "Invalid Stripe signature."
      ) {
        return new Response(JSON.stringify({ error: "invalid_signature" }), {
          status: 400,
          headers: { "Content-Type": "application/json" },
        });
      }
      if (name === "PurchaseUnavailableError" || message === PURCHASE_UNAVAILABLE) {
        return new Response(JSON.stringify({ error: "unavailable" }), {
          status: 503,
          headers: { "Content-Type": "application/json" },
        });
      }
      return new Response(JSON.stringify({ error: "webhook_failed" }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }
  }),
});

http.route({
  path: "/google-play-rtdn",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const authorization = request.headers.get("Authorization") ?? "";
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return new Response(JSON.stringify({ error: GOOGLE_PLAY_RTDN_INVALID }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }
    try {
      const result = await ctx.runAction(internal.googlePlay.processRtdn, {
        authorization,
        body,
      });
      return new Response(JSON.stringify(result), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } catch (error) {
      const name =
        error !== null &&
        typeof error === "object" &&
        "name" in error &&
        typeof error.name === "string"
          ? error.name
          : "";
      const message = error instanceof Error ? error.message : "";
      if (
        name === "GooglePlayRtdnUnauthorizedError" ||
        message === GOOGLE_PLAY_RTDN_UNAUTHORIZED
      ) {
        return new Response(
          JSON.stringify({ error: GOOGLE_PLAY_RTDN_UNAUTHORIZED }),
          {
            status: 401,
            headers: { "Content-Type": "application/json" },
          },
        );
      }
      if (name === "GooglePlayRtdnError" || message === GOOGLE_PLAY_RTDN_INVALID) {
        return new Response(JSON.stringify({ error: GOOGLE_PLAY_RTDN_INVALID }), {
          status: 400,
          headers: { "Content-Type": "application/json" },
        });
      }
      if (
        name === "GooglePlayConfigError" ||
        message === GOOGLE_PLAY_RTDN_UNAVAILABLE ||
        message === GOOGLE_PLAY_UNAVAILABLE
      ) {
        return new Response(JSON.stringify({ error: "unavailable" }), {
          status: 503,
          headers: { "Content-Type": "application/json" },
        });
      }
      return new Response(JSON.stringify({ error: "rtdn_failed" }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }
  }),
});

export default http;
