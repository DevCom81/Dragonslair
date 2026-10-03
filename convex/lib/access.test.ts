import { describe, expect, test } from "vitest";
import { effectiveAccessLevel } from "./access";

describe("effectiveAccessLevel", () => {
  test("demo stays demo regardless of expiry", () => {
    expect(
      effectiveAccessLevel({
        accessLevel: "demo",
        expiresAt: Date.now() + 60_000,
        now: Date.now(),
      }),
    ).toBe("demo");
  });

  test("full without expiresAt stays full", () => {
    expect(effectiveAccessLevel({ accessLevel: "full" })).toBe("full");
  });

  test("full with future expiresAt stays full", () => {
    expect(
      effectiveAccessLevel({
        accessLevel: "full",
        expiresAt: 2_000,
        now: 1_000,
      }),
    ).toBe("full");
  });

  test("full with past expiresAt falls back to demo", () => {
    expect(
      effectiveAccessLevel({
        accessLevel: "full",
        expiresAt: 1_000,
        now: 2_000,
      }),
    ).toBe("demo");
  });
});
