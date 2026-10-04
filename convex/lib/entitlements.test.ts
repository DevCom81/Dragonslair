import { describe, expect, test } from "vitest";
import { computeGlobalEntitlement, sourceGrantsFull } from "./entitlements";

describe("LOT 9 entitlement recompute", () => {
  const now = 1_000_000;

  test("stripe only is full purchase", () => {
    const row = computeGlobalEntitlement({
      sources: [{ provider: "stripe", status: "active" }],
      now,
    });
    expect(row.accessLevel).toBe("full");
    expect(row.source).toBe("purchase");
    expect(row.expiresAt).toBeUndefined();
    expect(row.metadata.active_sources).toEqual(["stripe"]);
    expect(row.metadata.provider).toBe("stripe");
  });

  test("google only is full", () => {
    const row = computeGlobalEntitlement({
      sources: [{ provider: "google_play", status: "active" }],
      now,
    });
    expect(row.accessLevel).toBe("full");
    expect(row.metadata.active_sources).toEqual(["google_play"]);
  });

  test("revoked stripe with active google stays full", () => {
    const row = computeGlobalEntitlement({
      sources: [
        { provider: "stripe", status: "revoked" },
        { provider: "google_play", status: "active" },
      ],
      now,
    });
    expect(row.accessLevel).toBe("full");
    expect(row.metadata.active_sources).toEqual(["google_play"]);
  });

  test("both revoked is demo", () => {
    const row = computeGlobalEntitlement({
      sources: [
        { provider: "stripe", status: "revoked" },
        { provider: "google_play", status: "revoked" },
      ],
      now,
    });
    expect(row.accessLevel).toBe("demo");
    expect(row.source).toBe("default");
    expect(row.metadata.active_sources).toEqual([]);
  });

  test("manual only is admin full", () => {
    const row = computeGlobalEntitlement({
      sources: [{ provider: "manual", status: "active" }],
      now,
    });
    expect(row.accessLevel).toBe("full");
    expect(row.source).toBe("admin");
  });

  test("canceled without period end does not grant", () => {
    expect(
      sourceGrantsFull({ provider: "stripe", status: "canceled" }, now),
    ).toBe(false);
  });

  test("canceled with future period end grants", () => {
    expect(
      sourceGrantsFull(
        { provider: "stripe", status: "canceled", currentPeriodEnd: now + 1 },
        now,
      ),
    ).toBe(true);
  });
});
