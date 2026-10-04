export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function playObfuscatedAccountId(rawId: string): Promise<string> {
  const trimmed = rawId.trim();
  if (!trimmed) {
    return "";
  }
  return await sha256Hex(`dragons_lair:${trimmed}`);
}

export async function purchaseTokenFingerprint(
  purchaseToken: string,
): Promise<string> {
  return await sha256Hex(purchaseToken);
}

export async function playAccountHashesForUser(user: {
  workosSubject: string;
  legacyUuid?: string;
}): Promise<{ workosHash: string; legacyHash?: string; accepted: string[] }> {
  const workosHash = await playObfuscatedAccountId(user.workosSubject);
  const accepted = [workosHash];
  let legacyHash: string | undefined;
  if (user.legacyUuid) {
    legacyHash = await playObfuscatedAccountId(user.legacyUuid);
    if (legacyHash && !accepted.includes(legacyHash)) {
      accepted.push(legacyHash);
    }
  }
  return { workosHash, legacyHash, accepted };
}

export function playAccountBindingMatches(
  actual: string,
  acceptedHashes: string[],
): boolean {
  const hash = actual.trim();
  if (!hash) {
    return false;
  }
  return acceptedHashes.includes(hash);
}
