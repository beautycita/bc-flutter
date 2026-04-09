import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, handleCorsPreflightIfOptions } from "../_shared/cors.ts";


function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders(req), "Content-Type": "application/json" },
  });
}

/** Generate cryptographically random bytes, return as base64url string. */
function randomChallenge(length = 32): string {
  const buf = new Uint8Array(length);
  crypto.getRandomValues(buf);
  return base64urlEncode(buf);
}

/** Base64url encode a Uint8Array (no padding). */
function base64urlEncode(buf: Uint8Array): string {
  let binary = "";
  for (const byte of buf) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

/** Base64url decode to Uint8Array. */
function base64urlDecode(str: string): Uint8Array {
  // Restore padding
  let s = str.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  const binary = atob(s);
  const buf = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) buf[i] = binary.charCodeAt(i);
  return buf;
}

// ── Minimal CBOR decoder (handles attestation objects) ──────────────────────

function decodeCBOR(data: Uint8Array): any {
  let offset = 0;

  function readUint8(): number {
    return data[offset++];
  }

  function readUint16(): number {
    const val = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    return val;
  }

  function readUint32(): number {
    const val =
      (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
    offset += 4;
    return val >>> 0; // unsigned
  }

  function readBytes(n: number): Uint8Array {
    const slice = data.slice(offset, offset + n);
    offset += n;
    return slice;
  }

  function readValue(): any {
    const initial = readUint8();
    const majorType = initial >> 5;
    const additional = initial & 0x1f;

    let length: number;
    if (additional < 24) {
      length = additional;
    } else if (additional === 24) {
      length = readUint8();
    } else if (additional === 25) {
      length = readUint16();
    } else if (additional === 26) {
      length = readUint32();
    } else {
      throw new Error(`CBOR: unsupported additional info ${additional}`);
    }

    switch (majorType) {
      case 0: // unsigned int
        return length;
      case 1: // negative int
        return -1 - length;
      case 2: // byte string
        return readBytes(length);
      case 3: // text string
        return new TextDecoder().decode(readBytes(length));
      case 4: { // array
        const arr: any[] = [];
        for (let i = 0; i < length; i++) arr.push(readValue());
        return arr;
      }
      case 5: { // map
        const map: Record<string | number, any> = {};
        for (let i = 0; i < length; i++) {
          const key = readValue();
          const val = readValue();
          map[key] = val;
        }
        return map;
      }
      case 6: // tag — skip tag number, read value
        return readValue();
      case 7: // simple/float
        if (additional === 20) return false;
        if (additional === 21) return true;
        if (additional === 22) return null;
        return length;
      default:
        throw new Error(`CBOR: unsupported major type ${majorType}`);
    }
  }

  return readValue();
}

// ── COSE key to CryptoKey ───────────────────────────────────────────────────

/** Extract the raw public key from a COSE key map (ES256 / alg -7). */
function coseKeyToRaw(coseMap: Record<number, any>): Uint8Array {
  // COSE key parameters: 1=kty, 3=alg, -1=crv, -2=x, -3=y
  const x = coseMap[-2] as Uint8Array;
  const y = coseMap[-3] as Uint8Array;
  if (!x || !y) throw new Error("Missing x/y in COSE key");
  // Uncompressed point: 0x04 || x || y
  const raw = new Uint8Array(1 + x.length + y.length);
  raw[0] = 0x04;
  raw.set(x, 1);
  raw.set(y, 1 + x.length);
  return raw;
}

/** Import a raw EC P-256 public key for signature verification. */
async function importPublicKey(rawKey: Uint8Array): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    rawKey,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["verify"]
  );
}

// ── Authenticator data parsing ──────────────────────────────────────────────

interface AuthData {
  rpIdHash: Uint8Array;
  flags: number;
  signCount: number;
  attestedCredData?: {
    aaguid: Uint8Array;
    credentialId: Uint8Array;
    publicKey: Uint8Array; // raw uncompressed point
  };
}

function parseAuthenticatorData(buf: Uint8Array): AuthData {
  const rpIdHash = buf.slice(0, 32);
  const flags = buf[32];
  const signCount =
    (buf[33] << 24) | (buf[34] << 16) | (buf[35] << 8) | buf[36];

  const result: AuthData = { rpIdHash, flags, signCount: signCount >>> 0 };

  // Bit 6 of flags = attested credential data present
  if (flags & 0x40) {
    const aaguid = buf.slice(37, 53);
    const credIdLen = (buf[53] << 8) | buf[54];
    const credentialId = buf.slice(55, 55 + credIdLen);

    // The rest is the COSE public key
    const coseBytes = buf.slice(55 + credIdLen);
    const coseMap = decodeCBOR(coseBytes);
    const publicKey = coseKeyToRaw(coseMap);

    result.attestedCredData = { aaguid, credentialId, publicKey };
  }

  return result;
}

// ── Main handler ────────────────────────────────────────────────────────────

serve(async (req) => {
  const _pre = handleCorsPreflightIfOptions(req);
  if (_pre) return _pre;

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const body = await req.json();
    const { action } = body;

    // ===== REGISTER CHALLENGE =====
    // Requires authenticated user (they register email/password first, then add a passkey)
    if (action === "register-challenge") {
      const authHeader = req.headers.get("Authorization") ?? "";
      const token = authHeader.replace("Bearer ", "");
      if (!token) return json({ error: "Authorization required" }, 401);

      const {
        data: { user },
        error: authError,
      } = await supabase.auth.getUser(token);
      if (authError || !user) return json({ error: "Invalid token" }, 401);

      const challenge = randomChallenge();

      // Store challenge temporarily
      const { error: insertErr } = await supabase
        .from("webauthn_challenges")
        .insert({
          challenge,
          user_id: user.id,
          type: "register",
        });

      if (insertErr) throw insertErr;

      // Clean up expired challenges (fire-and-forget)
      supabase
        .from("webauthn_challenges")
        .delete()
        .lt("expires_at", new Date().toISOString())
        .then(() => {});

      return json({
        challenge,
        rp: { name: "BeautyCita", id: "beautycita.com" },
        user: {
          id: base64urlEncode(new TextEncoder().encode(user.id)),
          name: user.email ?? user.id,
          displayName:
            user.user_metadata?.display_name ?? user.email ?? "Usuario",
        },
      });
    }

    // ===== REGISTER VERIFY =====
    // Verify the browser's attestation response and store the credential
    if (action === "register-verify") {
      const authHeader = req.headers.get("Authorization") ?? "";
      const token = authHeader.replace("Bearer ", "");
      if (!token) return json({ error: "Authorization required" }, 401);

      const {
        data: { user },
        error: authError,
      } = await supabase.auth.getUser(token);
      if (authError || !user) return json({ error: "Invalid token" }, 401);

      const {
        credential_id,
        attestation_object,
        client_data_json,
        device_name,
      } = body;

      if (!credential_id || !attestation_object || !client_data_json) {
        return json({ error: "Missing credential data" }, 400);
      }

      // Decode clientDataJSON and verify
      const clientDataBytes = base64urlDecode(client_data_json);
      const clientData = JSON.parse(new TextDecoder().decode(clientDataBytes));

      if (clientData.type !== "webauthn.create") {
        return json({ error: "Invalid ceremony type" }, 400);
      }

      // Verify the challenge matches one we issued
      const { data: challengeRow, error: chalErr } = await supabase
        .from("webauthn_challenges")
        .select("id, challenge")
        .eq("user_id", user.id)
        .eq("type", "register")
        .eq("challenge", clientData.challenge)
        .gt("expires_at", new Date().toISOString())
        .limit(1)
        .maybeSingle();

      if (chalErr) throw chalErr;
      if (!challengeRow) {
        return json({ error: "Challenge not found or expired" }, 400);
      }

      // Delete the used challenge
      await supabase.from("webauthn_challenges").delete().eq("id", challengeRow.id);

      // Parse attestation object
      const attestBytes = base64urlDecode(attestation_object);
      const attestObj = decodeCBOR(attestBytes);
      const authDataBytes = attestObj.authData as Uint8Array;

      if (!authDataBytes) {
        return json({ error: "Missing authData in attestation" }, 400);
      }

      const authData = parseAuthenticatorData(authDataBytes);

      if (!authData.attestedCredData) {
        return json({ error: "No attested credential data" }, 400);
      }

      // Verify rpIdHash
      const expectedRpIdHash = new Uint8Array(
        await crypto.subtle.digest(
          "SHA-256",
          new TextEncoder().encode("beautycita.com")
        )
      );
      const rpMatch = authData.rpIdHash.every(
        (b, i) => b === expectedRpIdHash[i]
      );
      if (!rpMatch) {
        return json({ error: "RP ID mismatch" }, 400);
      }

      // Store credential
      const rawKey = authData.attestedCredData.publicKey;

      const { error: credErr } = await supabase
        .from("webauthn_credentials")
        .insert({
          user_id: user.id,
          credential_id,
          public_key: `\\x${Array.from(rawKey)
            .map((b) => b.toString(16).padStart(2, "0"))
            .join("")}`,
          sign_count: authData.signCount,
          device_name: device_name ?? null,
        });

      if (credErr) {
        if (credErr.code === "23505") {
          // Duplicate credential
          return json({ error: "Credential already registered" }, 409);
        }
        throw credErr;
      }

      return json({ success: true });
    }

    // ===== LOGIN CHALLENGE =====
    // No auth required — this IS the login
    if (action === "login-challenge") {
      const challenge = randomChallenge();

      const { error: insertErr } = await supabase
        .from("webauthn_challenges")
        .insert({
          challenge,
          type: "login",
        });

      if (insertErr) throw insertErr;

      // Clean up expired challenges (fire-and-forget)
      supabase
        .from("webauthn_challenges")
        .delete()
        .lt("expires_at", new Date().toISOString())
        .then(() => {});

      return json({
        challenge,
        rpId: "beautycita.com",
      });
    }

    // ===== LOGIN VERIFY =====
    // Verify the browser's assertion and issue a session
    if (action === "login-verify") {
      const {
        credential_id,
        authenticator_data,
        client_data_json,
        signature,
      } = body;

      if (
        !credential_id ||
        !authenticator_data ||
        !client_data_json ||
        !signature
      ) {
        return json({ error: "Missing assertion data" }, 400);
      }

      // Look up credential
      const { data: cred, error: credErr } = await supabase
        .from("webauthn_credentials")
        .select("id, user_id, public_key, sign_count")
        .eq("credential_id", credential_id)
        .maybeSingle();

      if (credErr) throw credErr;
      if (!cred) {
        return json({ error: "Credential not found" }, 404);
      }

      // Decode clientDataJSON
      const clientDataBytes = base64urlDecode(client_data_json);
      const clientData = JSON.parse(new TextDecoder().decode(clientDataBytes));

      if (clientData.type !== "webauthn.get") {
        return json({ error: "Invalid ceremony type" }, 400);
      }

      // Verify the challenge matches
      const { data: challengeRow, error: chalErr } = await supabase
        .from("webauthn_challenges")
        .select("id, challenge")
        .eq("type", "login")
        .eq("challenge", clientData.challenge)
        .gt("expires_at", new Date().toISOString())
        .limit(1)
        .maybeSingle();

      if (chalErr) throw chalErr;
      if (!challengeRow) {
        return json({ error: "Challenge not found or expired" }, 400);
      }

      // Delete the used challenge
      await supabase.from("webauthn_challenges").delete().eq("id", challengeRow.id);

      // Parse authenticator data
      const authDataBytes = base64urlDecode(authenticator_data);
      const authData = parseAuthenticatorData(authDataBytes);

      // Verify rpIdHash
      const expectedRpIdHash = new Uint8Array(
        await crypto.subtle.digest(
          "SHA-256",
          new TextEncoder().encode("beautycita.com")
        )
      );
      const rpMatch = authData.rpIdHash.every(
        (b, i) => b === expectedRpIdHash[i]
      );
      if (!rpMatch) {
        return json({ error: "RP ID mismatch" }, 400);
      }

      // Verify signature
      // Signature is over: authenticatorData || SHA-256(clientDataJSON)
      const clientDataHash = new Uint8Array(
        await crypto.subtle.digest("SHA-256", clientDataBytes)
      );
      const signedData = new Uint8Array(
        authDataBytes.length + clientDataHash.length
      );
      signedData.set(authDataBytes, 0);
      signedData.set(clientDataHash, authDataBytes.length);

      // Import the stored public key
      const storedKeyHex = (cred.public_key as string).replace(/^\\x/, "");
      const storedKeyBytes = new Uint8Array(
        storedKeyHex.match(/.{2}/g)!.map((h: string) => parseInt(h, 16))
      );
      const pubKey = await importPublicKey(storedKeyBytes);

      const sigBytes = base64urlDecode(signature);

      // WebAuthn uses DER-encoded ECDSA signatures; Web Crypto expects IEEE P1363
      const p1363Sig = derToP1363(sigBytes);

      const valid = await crypto.subtle.verify(
        { name: "ECDSA", hash: "SHA-256" },
        pubKey,
        p1363Sig,
        signedData
      );

      if (!valid) {
        return json({ error: "Invalid signature" }, 400);
      }

      // Verify sign count (replay protection)
      if (authData.signCount > 0 && authData.signCount <= cred.sign_count) {
        return json({ error: "Possible credential cloning detected" }, 400);
      }

      // Update sign count
      await supabase
        .from("webauthn_credentials")
        .update({ sign_count: authData.signCount })
        .eq("id", cred.id);

      // Generate a session for this user via magic link
      const { data: userData, error: userErr } =
        await supabase.auth.admin.getUserById(cred.user_id);
      if (userErr || !userData?.user) {
        return json({ error: "User not found" }, 404);
      }

      const email = userData.user.email;
      if (!email) {
        return json({ error: "User has no email" }, 400);
      }

      // Generate magic link OTP
      const { data: linkData, error: linkError } =
        await supabase.auth.admin.generateLink({
          type: "magiclink",
          email,
        });

      if (linkError) {
        console.error("generateLink error:", linkError);
        return json({ error: "Failed to generate auth session" }, 500);
      }

      const emailOtp = linkData?.properties?.email_otp ?? "";
      if (!emailOtp) {
        return json({ error: "Auth generation failed" }, 500);
      }

      return json({
        email,
        email_otp: emailOtp,
      });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (err) {
    console.error("webauthn error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});

// ── DER to IEEE P1363 signature conversion ──────────────────────────────────

/** Convert a DER-encoded ECDSA signature to IEEE P1363 format (r || s, 32 bytes each). */
function derToP1363(der: Uint8Array): Uint8Array {
  // DER: 0x30 <len> 0x02 <rlen> <r> 0x02 <slen> <s>
  let offset = 0;
  if (der[offset++] !== 0x30) throw new Error("Invalid DER signature");
  offset++; // skip total length

  if (der[offset++] !== 0x02) throw new Error("Invalid DER signature (r tag)");
  const rLen = der[offset++];
  let r = der.slice(offset, offset + rLen);
  offset += rLen;

  if (der[offset++] !== 0x02) throw new Error("Invalid DER signature (s tag)");
  const sLen = der[offset++];
  let s = der.slice(offset, offset + sLen);

  // Strip leading zero bytes (DER uses them for positive sign)
  if (r.length > 32) r = r.slice(r.length - 32);
  if (s.length > 32) s = s.slice(s.length - 32);

  // Pad to 32 bytes
  const result = new Uint8Array(64);
  result.set(r, 32 - r.length);
  result.set(s, 64 - s.length);
  return result;
}
