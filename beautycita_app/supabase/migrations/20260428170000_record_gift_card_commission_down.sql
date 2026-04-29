-- beautycita_app/supabase/migrations/20260428170000_record_gift_card_commission_down.sql
DROP FUNCTION IF EXISTS record_gift_card_commission(uuid, text, numeric, text, text, text, timestamptz);
