import Stripe from "stripe";
import { PurchaseSignatureError, PurchaseUnavailableError } from "./errors";

export async function constructStripeEvent(args: {
  payload: string;
  signature: string;
  secret: string;
}): Promise<Stripe.Event> {
  if (!args.secret) {
    throw new PurchaseUnavailableError();
  }
  if (!args.signature.trim()) {
    throw new PurchaseSignatureError();
  }
  try {
    return await Stripe.webhooks.constructEventAsync(
      args.payload,
      args.signature,
      args.secret,
      undefined,
      Stripe.createSubtleCryptoProvider(),
    );
  } catch {
    throw new PurchaseSignatureError();
  }
}
