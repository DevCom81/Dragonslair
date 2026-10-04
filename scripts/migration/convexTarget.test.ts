// @vitest-environment node
import { describe, expect, test } from "vitest";
import {
  CONVEX_PRODUCTION_CONFIRM_VALUE,
  isProductionConvexSelector,
  isProductionConvexTarget,
} from "./convexTarget";

describe("LOT 14B production target detection", () => {
  test("dev dusty-rabbit is not production", () => {
    expect(isProductionConvexSelector("dev:dusty-rabbit-684")).toBe(false);
    expect(
      isProductionConvexTarget({
        target: "dev:dusty-rabbit-684",
        deployment: "dev:dusty-rabbit-684",
      }),
    ).toBe(false);
  });

  test("Convex prod: prefix is production", () => {
    expect(isProductionConvexSelector("prod:PLACEHOLDER_DEPLOYMENT")).toBe(true);
  });

  test("explicit CONVEX_PRODUCTION_DEPLOYMENT pins a future selector", () => {
    expect(
      isProductionConvexSelector("happy-animal-123", "happy-animal-123"),
    ).toBe(true);
    expect(
      isProductionConvexSelector("dev:dusty-rabbit-684", "happy-animal-123"),
    ).toBe(false);
  });

  test("arming phrase is non-secret and exact", () => {
    expect(CONVEX_PRODUCTION_CONFIRM_VALUE).toBe("DRAGONSLAIR_PRODUCTION");
  });
});
