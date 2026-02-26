-- =============================================================================
-- Migration: 20260211000003_profile_stripe_customer.sql
-- Description: Add Stripe customer ID to profiles for payment tracking
-- =============================================================================

alter table public.profiles
  add column if not exists stripe_customer_id text;

create unique index if not exists idx_profiles_stripe_customer
  on public.profiles (stripe_customer_id) where stripe_customer_id is not null;

comment on column public.profiles.stripe_customer_id is 'Stripe Customer ID for recurring payments and saved cards';
