// Verifies a Firebase ID token in a Deno edge function without the full
// Firebase Admin SDK (which isn't Deno-native). This validates the JWT
// signature against Google's published public keys and checks standard
// claims (iss, aud, exp). Server-side verification only — never trust a
// client-supplied uid/email without this check.
//
// Required env var: FIREBASE_PROJECT_ID

import { create, verify, decode } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const GOOGLE_CERTS_URL =
  "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com";

let cachedCerts: { certs: Record<string, string>; fetchedAt: number } | null = null;
const CERTS_TTL_MS = 60 * 60 * 1000; // 1 hour, matches Google's typical cache-control

async function getGoogleCerts(): Promise<Record<string, string>> {
  if (cachedCerts && Date.now() - cachedCerts.fetchedAt < CERTS_TTL_MS) {
    return cachedCerts.certs;
  }
  const res = await fetch(GOOGLE_CERTS_URL);
  if (!res.ok) {
    throw new Error("Failed to fetch Firebase signing certificates.");
  }
  const certs = await res.json();
  cachedCerts = { certs, fetchedAt: Date.now() };
  return certs;
}

export interface DecodedFirebaseToken {
  uid: string;
  email?: string;
  phone_number?: string;
  [key: string]: unknown;
}

/**
 * Verifies a Firebase ID token's signature and standard claims.
 * Throws if the token is invalid, expired, or from the wrong project.
 */
export async function verifyFirebaseToken(idToken: string): Promise<DecodedFirebaseToken> {
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  if (!projectId) {
    throw new Error("FIREBASE_PROJECT_ID is not configured.");
  }

  const [header] = decode(idToken) as [Record<string, unknown>, Record<string, unknown>, Uint8Array];
  const kid = header?.kid as string | undefined;
  if (!kid) {
    throw new Error("Token missing key id.");
  }

  const certs = await getGoogleCerts();
  const pem = certs[kid];
  if (!pem) {
    throw new Error("No matching signing certificate for this token.");
  }

  const cryptoKey = await importPemCertPublicKey(pem);

  const payload = (await verify(idToken, cryptoKey)) as Record<string, unknown>;

  if (payload.aud !== projectId) {
    throw new Error("Token audience does not match this project.");
  }
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new Error("Token issuer is invalid.");
  }
  const now = Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== "number" || payload.exp < now) {
    throw new Error("Token has expired.");
  }
  if (typeof payload.sub !== "string" || payload.sub.length === 0) {
    throw new Error("Token missing subject (uid).");
  }

  return {
    uid: payload.sub,
    email: payload.email as string | undefined,
    phone_number: payload.phone_number as string | undefined,
    ...payload,
  };
}

async function importPemCertPublicKey(pem: string): Promise<CryptoKey> {
  // Extract the public key from the X.509 certificate PEM and import it for RS256 verification.
  // Use Deno's node:crypto compatibility layer to parse the X.509 certificate
  // into its SPKI public key (this is the production path, see note below).
  const { X509Certificate } = await import("node:crypto");
  const cert = new X509Certificate(pem);
  const spki = cert.publicKey.export({ format: "der", type: "spki" });

  // Convert the Node Buffer into a standard Uint8Array so WebCrypto accepts it.
  const spkiBytes = Uint8Array.from(spki);

  return await crypto.subtle.importKey(
    "spki",
    spkiBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );
}
