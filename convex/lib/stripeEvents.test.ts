import { describe, expect, test } from "vitest";
import {
  checkoutIdentityMatchesContract,
  parseCheckoutSession,
  parseRefundCharge,
  sessionHasExpectedPrice,
} from "./stripeEvents";

describe("LOT 9 stripe event parsers", () => {
  test("checkout completed reads user from session", () => {
    const parsed = parseCheckoutSession({
      type: "checkout.session.completed",
      data: {
        object: {
          id: "cs_test",
          payment_status: "paid",
          mode: "payment",
          client_reference_id: "user-1",
        },
      },
    });
    expect(parsed?.userId).toBe("user-1");
    expect(parsed?.sessionId).toBe("cs_test");
  });

  test("unrelated event is ignored", () => {
    expect(
      parseCheckoutSession({ type: "invoice.paid", data: { object: {} } }),
    ).toBeNull();
    expect(
      parseRefundCharge({ type: "invoice.paid", data: { object: {} } }),
    ).toBeNull();
  });

  test("full refund maps user from charge metadata", () => {
    const parsed = parseRefundCharge({
      type: "charge.refunded",
      data: {
        object: {
          id: "ch_test",
          refunded: true,
          metadata: { user_id: "user-1" },
        },
      },
    });
    expect(parsed?.userId).toBe("user-1");
  });

  test("partial refund does not inactivate", () => {
    expect(
      parseRefundCharge({
        type: "charge.refunded",
        data: {
          object: {
            refunded: false,
            metadata: { user_id: "user-1" },
          },
        },
      }),
    ).toBeNull();
  });

  test("unpaid checkout is ignored", () => {
    for (const status of ["unpaid", "processing", "failed"]) {
      expect(
        parseCheckoutSession({
          type: "checkout.session.completed",
          data: {
            object: {
              id: "cs_test",
              payment_status: status,
              client_reference_id: "user-1",
            },
          },
        }),
      ).toBeNull();
    }
  });

  test("metadata access_level without user is ignored", () => {
    expect(
      parseCheckoutSession({
        type: "checkout.session.completed",
        data: {
          object: {
            id: "cs_test",
            payment_status: "paid",
            metadata: { access_level: "full" },
          },
        },
      })?.userId,
    ).toBeNull();
  });

  test("expected price must match", () => {
    expect(sessionHasExpectedPrice(["price_other"], "price_test")).toBe(false);
    expect(sessionHasExpectedPrice(["price_test"], "price_test")).toBe(true);
    expect(sessionHasExpectedPrice([], "price_test")).toBe(false);
  });

  test("checkout identity contract requires aligned refs", () => {
    expect(
      checkoutIdentityMatchesContract({
        clientReferenceId: "u1",
        metadataUserId: "u1",
        workosSubject: "sub",
      }),
    ).toBe(true);
    expect(
      checkoutIdentityMatchesContract({
        clientReferenceId: "u1",
        metadataUserId: "u2",
        workosSubject: "sub",
      }),
    ).toBe(false);
    expect(
      checkoutIdentityMatchesContract({
        clientReferenceId: "u1",
        metadataUserId: "u1",
        workosSubject: null,
      }),
    ).toBe(false);
  });
});
