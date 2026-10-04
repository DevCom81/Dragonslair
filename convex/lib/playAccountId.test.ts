import { describe, expect, test } from "vitest";
import {
  playAccountBindingMatches,
  playAccountHashesForUser,
  playObfuscatedAccountId,
} from "./playAccountId";

describe("playAccountId dual-hash", () => {
  test("legacy formula is sha256 of dragons_lair:{legacyUuid}", async () => {
    const hash = await playObfuscatedAccountId(
      "11111111-1111-4111-8111-111111111111",
    );
    expect(hash).toHaveLength(64);
    expect(hash).toBe(
      await playObfuscatedAccountId("11111111-1111-4111-8111-111111111111"),
    );
    expect(hash).not.toBe(
      await playObfuscatedAccountId("user_01ALICE"),
    );
  });

  test("WorkOS hash does not use Convex document ids", async () => {
    const hashes = await playAccountHashesForUser({
      workosSubject: "user_01ALICE",
    });
    expect(hashes.workosHash).toBe(await playObfuscatedAccountId("user_01ALICE"));
    expect(hashes.accepted).toEqual([hashes.workosHash]);
    expect(hashes.legacyHash).toBeUndefined();
  });

  test("same user accepts WorkOS hash and legacy hash only", async () => {
    const hashes = await playAccountHashesForUser({
      workosSubject: "user_01ALICE",
      legacyUuid: "11111111-1111-4111-8111-111111111111",
    });
    expect(hashes.accepted).toHaveLength(2);
    expect(
      playAccountBindingMatches(hashes.workosHash, hashes.accepted),
    ).toBe(true);
    expect(
      playAccountBindingMatches(hashes.legacyHash ?? "", hashes.accepted),
    ).toBe(true);
    const other = await playObfuscatedAccountId("user_01BOB");
    expect(playAccountBindingMatches(other, hashes.accepted)).toBe(false);
    expect(playAccountBindingMatches("", hashes.accepted)).toBe(false);
  });
});
