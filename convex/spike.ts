import { action, mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const whoami = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      return {
        authenticated: false,
        subject: null,
        issuer: null,
      };
    }
    return {
      authenticated: true,
      subject: identity.subject,
      issuer: identity.issuer,
    };
  },
});

export const getMarker = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      return {
        authenticated: false,
        subject: null,
        marker: null,
      };
    }
    const row = await ctx.db
      .query("spikeMarkers")
      .withIndex("by_subject", (q) => q.eq("subject", identity.subject))
      .unique();
    return {
      authenticated: true,
      subject: identity.subject,
      marker: row?.marker ?? null,
    };
  },
});

export const setMarker = mutation({
  args: {
    marker: v.string(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      throw new Error("Not authenticated.");
    }
    const marker = args.marker.trim();
    if (!marker) {
      throw new Error("Marker is required.");
    }
    const existing = await ctx.db
      .query("spikeMarkers")
      .withIndex("by_subject", (q) => q.eq("subject", identity.subject))
      .unique();
    if (existing === null) {
      await ctx.db.insert("spikeMarkers", {
        subject: identity.subject,
        marker,
      });
    } else {
      await ctx.db.patch(existing._id, { marker });
    }
    return {
      subject: identity.subject,
      marker,
    };
  },
});

export const pingAuth = action({
  args: {
    probe: v.string(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      throw new Error("Not authenticated.");
    }
    const probe = args.probe.trim();
    if (!probe) {
      throw new Error("Probe is required.");
    }
    return {
      subject: identity.subject,
      probe,
    };
  },
});
