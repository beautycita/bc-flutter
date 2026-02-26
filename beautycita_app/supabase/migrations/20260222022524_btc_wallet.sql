-- =============================================================================
-- BTC Wallet: TOTP 2FA + per-user addresses + deposit tracking
-- =============================================================================

-- 1. TOTP secrets (server-only, never exposed to client)
CREATE TABLE public.user_totp_secrets (
  id           uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      uuid        NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  secret_enc   text        NOT NULL,
  iv           text        NOT NULL,
  is_verified  boolean     NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now(),
  verified_at  timestamptz,
  CONSTRAINT user_totp_secrets_user_unique UNIQUE (user_id)
);

ALTER TABLE public.user_totp_secrets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_totp_secrets FROM anon, authenticated;

-- 2. BTC addresses (per-user, multiple via rotation)
CREATE TABLE public.btc_addresses (
  id           uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      uuid        NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  address      text        NOT NULL,
  label        text,
  is_current   boolean     NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT btc_addresses_address_unique UNIQUE (address)
);

CREATE INDEX idx_btc_addresses_user ON public.btc_addresses (user_id);
CREATE INDEX idx_btc_addresses_current ON public.btc_addresses (user_id, is_current) WHERE is_current = true;

ALTER TABLE public.btc_addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "btc_addresses_select_own" ON public.btc_addresses
  FOR SELECT USING (auth.uid() = user_id);

REVOKE INSERT, UPDATE, DELETE ON public.btc_addresses FROM anon, authenticated;

-- 3. BTC deposits (tracked by polling BTCPay wallet transactions)
CREATE TABLE public.btc_deposits (
  id              uuid           NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id         uuid           NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  address         text           NOT NULL REFERENCES btc_addresses(address),
  txid            text           NOT NULL,
  amount_btc      numeric(18,8)  NOT NULL DEFAULT 0,
  confirmations   int            NOT NULL DEFAULT 0,
  status          text           NOT NULL DEFAULT 'pending',
  detected_at     timestamptz    NOT NULL DEFAULT now(),
  confirmed_at    timestamptz,
  CONSTRAINT btc_deposits_tx_addr_unique UNIQUE (txid, address),
  CONSTRAINT btc_deposits_status_check CHECK (status IN ('pending', 'confirmed', 'orphaned'))
);

CREATE INDEX idx_btc_deposits_user ON public.btc_deposits (user_id);
CREATE INDEX idx_btc_deposits_pending ON public.btc_deposits (status) WHERE status = 'pending';

ALTER TABLE public.btc_deposits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "btc_deposits_select_own" ON public.btc_deposits
  FOR SELECT USING (auth.uid() = user_id);

REVOKE INSERT, UPDATE, DELETE ON public.btc_deposits FROM anon, authenticated;

-- 4. Balance view (convenience)
CREATE OR REPLACE VIEW public.btc_user_balance AS
SELECT
  user_id,
  COALESCE(SUM(amount_btc) FILTER (WHERE status = 'confirmed'), 0) AS confirmed_btc,
  COALESCE(SUM(amount_btc) FILTER (WHERE status = 'pending'), 0)   AS pending_btc,
  COUNT(*) FILTER (WHERE status = 'confirmed') AS confirmed_count,
  COUNT(*) FILTER (WHERE status = 'pending')   AS pending_count
FROM public.btc_deposits
GROUP BY user_id;
