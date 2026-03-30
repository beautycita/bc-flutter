-- Gift cards: salon owners can create gift cards that customers redeem as saldo credit
CREATE TABLE IF NOT EXISTS gift_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  code text NOT NULL UNIQUE,
  amount numeric(10,2) NOT NULL,
  remaining_amount numeric(10,2) NOT NULL,
  buyer_name text,
  recipient_name text,
  message text,
  is_active boolean NOT NULL DEFAULT true,
  redeemed_by uuid REFERENCES profiles(id),
  redeemed_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_gift_cards_code ON gift_cards(code);
CREATE INDEX IF NOT EXISTS idx_gift_cards_biz ON gift_cards(business_id);

ALTER TABLE gift_cards ENABLE ROW LEVEL SECURITY;

-- Owner and admin full access
CREATE POLICY gift_cards_owner ON gift_cards FOR ALL USING (
  business_id IN (SELECT id FROM businesses WHERE owner_id = auth.uid())
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin','superadmin'))
);

-- Any authenticated user can SELECT (needed for redemption lookup by code)
CREATE POLICY gift_cards_redeem ON gift_cards FOR SELECT USING (auth.uid() IS NOT NULL);
