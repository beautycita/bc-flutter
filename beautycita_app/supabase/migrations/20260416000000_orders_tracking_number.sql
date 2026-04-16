-- Add tracking_number column to orders table (was referenced in UI/service but missing from schema)
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS tracking_number text;
