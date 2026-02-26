// =============================================================================
// Shared TOTP utilities — AES-256-GCM encryption + RFC 6238 TOTP verification
// =============================================================================

const TOTP_KEY_HEX = Deno.env.get("TOTP_ENCRYPTION_KEY") ?? "";

// --- AES-256-GCM Encryption ---

async function getAesKey(): Promise<CryptoKey> {
  if (!TOTP_KEY_HEX || TOTP_KEY_HEX.length !== 64) {
    throw new Error("TOTP_ENCRYPTION_KEY must be 64 hex chars (32 bytes)");
  }
  const raw = new Uint8Array(32);
  for (let i = 0; i < 32; i++) {
    raw[i] = parseInt(TOTP_KEY_HEX.substring(i * 2, i * 2 + 2), 16);
  }
  return crypto.subtle.importKey("raw", raw, "AES-GCM", false, [
    "encrypt",
    "decrypt",
  ]);
}

export async function encryptSecret(
  plainSecret: string
): Promise<{ encrypted: string; iv: string }> {
  const key = await getAesKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(plainSecret);
  const cipher = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    encoded
  );
  return {
    encrypted: toBase64(new Uint8Array(cipher)),
    iv: toBase64(iv),
  };
}

export async function decryptSecret(
  encrypted: string,
  iv: string
): Promise<string> {
  const key = await getAesKey();
  const plain = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: fromBase64(iv) },
    key,
    fromBase64(encrypted)
  );
  return new TextDecoder().decode(plain);
}

// --- TOTP Secret Generation ---

const BASE32_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

export function generateTotpSecret(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(20));
  return base32Encode(bytes);
}

function base32Encode(data: Uint8Array): string {
  let bits = 0;
  let value = 0;
  let result = "";
  for (const byte of data) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      result += BASE32_CHARS[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) {
    result += BASE32_CHARS[(value << (5 - bits)) & 31];
  }
  return result;
}

function base32Decode(encoded: string): Uint8Array {
  const s = encoded.toUpperCase().replace(/=+$/, "");
  const out: number[] = [];
  let bits = 0;
  let value = 0;
  for (const c of s) {
    const idx = BASE32_CHARS.indexOf(c);
    if (idx === -1) continue;
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return new Uint8Array(out);
}

// --- RFC 6238 TOTP Verification ---

async function hmacSha1(
  key: Uint8Array,
  message: Uint8Array
): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", cryptoKey, message);
  return new Uint8Array(sig);
}

function generateTotp(secret: Uint8Array, counter: bigint): Promise<string> {
  const counterBytes = new Uint8Array(8);
  const view = new DataView(counterBytes.buffer);
  view.setBigUint64(0, counter, false);

  return hmacSha1(secret, counterBytes).then((hash) => {
    const offset = hash[hash.length - 1] & 0x0f;
    const code =
      (((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff)) %
      1000000;
    return code.toString().padStart(6, "0");
  });
}

/**
 * Verify a 6-digit TOTP code with ±1 step tolerance (30-second window).
 */
export async function verifyTotpCode(
  base32Secret: string,
  code: string
): Promise<boolean> {
  const secretBytes = base32Decode(base32Secret);
  const now = Math.floor(Date.now() / 1000);
  const period = 30;

  // Check current step and ±1 for clock drift tolerance
  for (const offset of [-1, 0, 1]) {
    const counter = BigInt(Math.floor(now / period) + offset);
    const expected = await generateTotp(secretBytes, counter);
    if (expected === code) return true;
  }
  return false;
}

/**
 * Build otpauth:// URI for QR code scanning with authenticator apps.
 */
export function buildOtpAuthUri(
  secret: string,
  userLabel: string
): string {
  const label = encodeURIComponent(`BeautyCita:${userLabel}`);
  return `otpauth://totp/${label}?secret=${secret}&issuer=BeautyCita&digits=6&period=30&algorithm=SHA1`;
}

// --- Base64 helpers ---

function toBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary);
}

function fromBase64(str: string): Uint8Array {
  const binary = atob(str);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}
