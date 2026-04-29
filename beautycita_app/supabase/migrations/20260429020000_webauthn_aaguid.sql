-- Store the authenticator AAGUID alongside each WebAuthn credential.
-- Required to track which authenticator family produced each passkey
-- (precondition for any future MDS allow-list policy).
-- ALTER only — no backfill. Existing credentials remain aaguid=NULL.

ALTER TABLE public.webauthn_credentials
  ADD COLUMN IF NOT EXISTS aaguid text;

COMMENT ON COLUMN public.webauthn_credentials.aaguid IS
  'Base64url-encoded 16-byte AAGUID extracted from attestation. NULL for credentials registered before this column existed or for authenticators that report all-zero AAGUIDs.';
