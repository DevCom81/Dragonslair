export const CHECKOUT_COMPLETED_TYPES = new Set([
  "checkout.session.completed",
  "checkout.session.async_payment_succeeded",
]);
export const STRIPE_INACTIVE_TYPES = new Set(["charge.refunded"]);

function asObject(value: unknown): Record<string, unknown> | null {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

function asNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export function eventObject(event: Record<string, unknown>): Record<string, unknown> | null {
  const data = asObject(event.data);
  if (data === null) {
    return null;
  }
  return asObject(data.object);
}

export function userIdFromStripeObject(
  object: Record<string, unknown>,
): string | null {
  const reference = asNonEmptyString(object.client_reference_id);
  if (reference !== null) {
    return reference;
  }
  const metadata = asObject(object.metadata);
  if (metadata === null) {
    return null;
  }
  return asNonEmptyString(metadata.user_id);
}

export function workosSubjectFromStripeObject(
  object: Record<string, unknown>,
): string | null {
  const metadata = asObject(object.metadata);
  if (metadata === null) {
    return null;
  }
  return asNonEmptyString(metadata.workos_subject);
}

export function parseCheckoutSession(event: Record<string, unknown>): {
  sessionId: string;
  paymentStatus: string;
  mode: string | null;
  clientReferenceId: string | null;
  metadataUserId: string | null;
  userId: string | null;
  workosSubject: string | null;
  paymentIntentId: string | null;
  priceIds: string[];
} | null {
  const eventType = String(event.type ?? "");
  if (!CHECKOUT_COMPLETED_TYPES.has(eventType)) {
    return null;
  }
  const session = eventObject(event);
  if (session === null) {
    return null;
  }
  const paymentStatus = String(session.payment_status ?? "");
  if (
    eventType === "checkout.session.completed" &&
    paymentStatus !== "paid" &&
    paymentStatus !== "no_payment_required"
  ) {
    return null;
  }
  const sessionId = asNonEmptyString(session.id);
  if (sessionId === null) {
    return null;
  }
  const paymentIntent = session.payment_intent;
  const paymentIntentId =
    typeof paymentIntent === "string"
      ? asNonEmptyString(paymentIntent)
      : asNonEmptyString(asObject(paymentIntent)?.id);
  return {
    sessionId,
    paymentStatus,
    mode: asNonEmptyString(session.mode),
    clientReferenceId: asNonEmptyString(session.client_reference_id),
    metadataUserId: asNonEmptyString(asObject(session.metadata)?.user_id),
    userId: userIdFromStripeObject(session),
    workosSubject: workosSubjectFromStripeObject(session),
    paymentIntentId,
    priceIds: priceIdsFromSession(session),
  };
}

export function parseRefundCharge(event: Record<string, unknown>): {
  chargeId: string;
  paymentIntentId: string | null;
  userId: string | null;
  workosSubject: string | null;
} | null {
  const eventType = String(event.type ?? "");
  if (!STRIPE_INACTIVE_TYPES.has(eventType)) {
    return null;
  }
  const charge = eventObject(event);
  if (charge === null) {
    return null;
  }
  if (charge.refunded !== true) {
    return null;
  }
  const chargeId = asNonEmptyString(charge.id) ?? "unknown";
  const paymentIntent = charge.payment_intent;
  const paymentIntentId =
    typeof paymentIntent === "string"
      ? asNonEmptyString(paymentIntent)
      : asNonEmptyString(asObject(paymentIntent)?.id);
  return {
    chargeId,
    paymentIntentId,
    userId: userIdFromStripeObject(charge),
    workosSubject: workosSubjectFromStripeObject(charge),
  };
}

export function priceIdsFromSession(session: Record<string, unknown>): string[] {
  const lineItems = asObject(session.line_items);
  const data = lineItems?.data;
  if (!Array.isArray(data)) {
    return [];
  }
  const ids: string[] = [];
  for (const item of data) {
    const row = asObject(item);
    if (row === null) {
      continue;
    }
    const price = row.price;
    if (typeof price === "string") {
      const id = asNonEmptyString(price);
      if (id !== null) {
        ids.push(id);
      }
      continue;
    }
    const nested = asNonEmptyString(asObject(price)?.id);
    if (nested !== null) {
      ids.push(nested);
    }
  }
  return ids;
}

export function sessionHasExpectedPrice(
  priceIds: string[],
  expectedPriceId: string,
): boolean {
  if (priceIds.length === 0) {
    return false;
  }
  return priceIds.includes(expectedPriceId);
}

/** createCheckout always writes the same Convex user on these three fields. */
export function checkoutIdentityMatchesContract(args: {
  clientReferenceId: string | null;
  metadataUserId: string | null;
  workosSubject: string | null;
}): args is {
  clientReferenceId: string;
  metadataUserId: string;
  workosSubject: string;
} {
  return (
    args.clientReferenceId !== null &&
    args.metadataUserId !== null &&
    args.workosSubject !== null &&
    args.clientReferenceId === args.metadataUserId
  );
}
