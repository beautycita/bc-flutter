-- CRM: Client management for salon owners
-- + Holiday/closure management

CREATE TABLE IF NOT EXISTS business_clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  client_name text NOT NULL,
  phone text,
  email text,
  preferred_staff_id uuid REFERENCES staff(id) ON DELETE SET NULL,
  preferred_services text[],
  notes text,
  tags text[],
  total_visits integer NOT NULL DEFAULT 0,
  total_spent numeric(12,2) NOT NULL DEFAULT 0,
  last_visit_at timestamptz,
  first_visit_at timestamptz,
  no_show_count integer NOT NULL DEFAULT 0,
  late_count integer NOT NULL DEFAULT 0,
  birthday date,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT business_clients_unique UNIQUE (business_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_business_clients_biz ON business_clients(business_id);
CREATE INDEX IF NOT EXISTS idx_business_clients_user ON business_clients(user_id);
CREATE INDEX IF NOT EXISTS idx_business_clients_phone ON business_clients(business_id, phone);

ALTER TABLE business_clients ENABLE ROW LEVEL SECURITY;
CREATE POLICY business_clients_owner_policy ON business_clients
  FOR ALL USING (
    business_id IN (SELECT id FROM businesses WHERE owner_id = auth.uid())
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
  );

CREATE TABLE IF NOT EXISTS business_closures (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  closure_date date NOT NULL,
  reason text,
  all_day boolean NOT NULL DEFAULT true,
  open_time time,
  close_time time,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT business_closures_unique UNIQUE (business_id, closure_date)
);

CREATE INDEX IF NOT EXISTS idx_business_closures_biz ON business_closures(business_id, closure_date);

ALTER TABLE business_closures ENABLE ROW LEVEL SECURITY;
CREATE POLICY business_closures_owner_policy ON business_closures
  FOR ALL USING (
    business_id IN (SELECT id FROM businesses WHERE owner_id = auth.uid())
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin'))
  );

-- Auto-populate business_clients from completed appointments
CREATE OR REPLACE FUNCTION update_business_client_on_completion()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client_name text;
  v_phone text;
  v_user_id uuid;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    v_user_id := NEW.user_id;
    SELECT COALESCE(p.full_name, p.username), p.phone
    INTO v_client_name, v_phone
    FROM profiles p WHERE p.id = v_user_id;
    IF v_client_name IS NULL THEN
      v_client_name := COALESCE(NEW.customer_name, 'Cliente');
    END IF;
    INSERT INTO business_clients (business_id, user_id, client_name, phone, total_visits, total_spent, last_visit_at, first_visit_at)
    VALUES (NEW.business_id, v_user_id, v_client_name, v_phone, 1, COALESCE(NEW.price, 0), NOW(), NOW())
    ON CONFLICT (business_id, user_id) DO UPDATE SET
      client_name = COALESCE(EXCLUDED.client_name, business_clients.client_name),
      phone = COALESCE(EXCLUDED.phone, business_clients.phone),
      total_visits = business_clients.total_visits + 1,
      total_spent = business_clients.total_spent + COALESCE(NEW.price, 0),
      last_visit_at = NOW(),
      updated_at = NOW();
  END IF;
  IF NEW.status = 'no_show' AND (OLD.status IS NULL OR OLD.status != 'no_show') AND NEW.user_id IS NOT NULL THEN
    UPDATE business_clients SET
      no_show_count = no_show_count + 1,
      updated_at = NOW()
    WHERE business_id = NEW.business_id AND user_id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_business_client ON appointments;
CREATE TRIGGER trg_update_business_client
  AFTER UPDATE ON appointments
  FOR EACH ROW
  EXECUTE FUNCTION update_business_client_on_completion();
