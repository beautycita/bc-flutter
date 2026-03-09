-- =============================================================================
-- Migration: 20260308000000_financial_reconciliation_views.sql
-- Description: Financial reconciliation views for the CEO dashboard.
--              Six views covering daily/monthly revenue, per-business revenue,
--              payment-level reconciliation, outstanding payouts, and platform
--              health metrics.
-- Access:      These views are intended for service_role only (admin/CEO dashboard).
--              They bypass RLS by design. Do NOT expose via anon or authenticated roles.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. v_daily_revenue — Daily revenue summary (bookings + product orders)
-- ---------------------------------------------------------------------------
-- Aggregates paid appointments and non-cancelled orders by calendar date.
-- All amounts in MXN.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_daily_revenue AS
WITH booking_daily AS (
  SELECT
    (a.paid_at AT TIME ZONE 'America/Mexico_City')::date AS revenue_date,
    COUNT(*)                                              AS booking_count,
    COALESCE(SUM(a.price), 0)                             AS booking_revenue,
    COALESCE(SUM(a.platform_fee), 0)                      AS booking_platform_fees,
    COALESCE(SUM(a.isr_withheld), 0)                      AS booking_isr,
    COALESCE(SUM(a.iva_withheld), 0)                      AS booking_iva,
    COALESCE(SUM(a.provider_net), 0)                       AS booking_provider_net
  FROM public.appointments a
  WHERE a.payment_status = 'paid'
    AND a.paid_at IS NOT NULL
  GROUP BY 1
),
order_daily AS (
  SELECT
    (o.created_at AT TIME ZONE 'America/Mexico_City')::date AS revenue_date,
    COUNT(*)                                                 AS product_orders,
    COALESCE(SUM(o.total_amount), 0)                         AS product_revenue,
    COALESCE(SUM(o.commission_amount), 0)                    AS product_platform_fees
  FROM public.orders o
  WHERE o.status NOT IN ('refunded', 'cancelled')
  GROUP BY 1
)
SELECT
  COALESCE(b.revenue_date, o.revenue_date)                          AS date,
  COALESCE(b.booking_count, 0)                                      AS booking_count,
  COALESCE(b.booking_revenue, 0)                                    AS booking_revenue,
  COALESCE(o.product_orders, 0)                                     AS product_orders,
  COALESCE(o.product_revenue, 0)                                    AS product_revenue,
  COALESCE(b.booking_revenue, 0) + COALESCE(o.product_revenue, 0)   AS total_revenue,
  COALESCE(b.booking_platform_fees, 0)
    + COALESCE(o.product_platform_fees, 0)                          AS platform_fees,
  COALESCE(b.booking_isr, 0)                                        AS isr_withheld,
  COALESCE(b.booking_iva, 0)                                        AS iva_withheld,
  COALESCE(b.booking_provider_net, 0)                                AS provider_payouts
FROM booking_daily b
FULL OUTER JOIN order_daily o ON b.revenue_date = o.revenue_date
ORDER BY 1 DESC;

COMMENT ON VIEW public.v_daily_revenue IS 'Daily revenue summary combining booking and product order revenue. Service-role only.';


-- ---------------------------------------------------------------------------
-- 2. v_monthly_revenue — Monthly revenue summary
-- ---------------------------------------------------------------------------
-- Same aggregation as daily but grouped by year + month.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_monthly_revenue AS
WITH booking_monthly AS (
  SELECT
    EXTRACT(YEAR  FROM a.paid_at AT TIME ZONE 'America/Mexico_City')::int AS yr,
    EXTRACT(MONTH FROM a.paid_at AT TIME ZONE 'America/Mexico_City')::int AS mo,
    COUNT(*)                                                               AS booking_count,
    COALESCE(SUM(a.price), 0)                                              AS booking_revenue,
    COALESCE(SUM(a.platform_fee), 0)                                       AS booking_platform_fees,
    COALESCE(SUM(a.isr_withheld), 0)                                       AS booking_isr,
    COALESCE(SUM(a.iva_withheld), 0)                                       AS booking_iva,
    COALESCE(SUM(a.provider_net), 0)                                        AS booking_provider_net
  FROM public.appointments a
  WHERE a.payment_status = 'paid'
    AND a.paid_at IS NOT NULL
  GROUP BY 1, 2
),
order_monthly AS (
  SELECT
    EXTRACT(YEAR  FROM o.created_at AT TIME ZONE 'America/Mexico_City')::int AS yr,
    EXTRACT(MONTH FROM o.created_at AT TIME ZONE 'America/Mexico_City')::int AS mo,
    COUNT(*)                                                                  AS product_orders,
    COALESCE(SUM(o.total_amount), 0)                                          AS product_revenue,
    COALESCE(SUM(o.commission_amount), 0)                                     AS product_platform_fees
  FROM public.orders o
  WHERE o.status NOT IN ('refunded', 'cancelled')
  GROUP BY 1, 2
)
SELECT
  COALESCE(b.yr, o.yr)                                                      AS year,
  COALESCE(b.mo, o.mo)                                                      AS month,
  COALESCE(b.booking_count, 0)                                               AS booking_count,
  COALESCE(b.booking_revenue, 0)                                             AS booking_revenue,
  COALESCE(o.product_orders, 0)                                              AS product_orders,
  COALESCE(o.product_revenue, 0)                                             AS product_revenue,
  COALESCE(b.booking_revenue, 0) + COALESCE(o.product_revenue, 0)            AS total_revenue,
  COALESCE(b.booking_platform_fees, 0)
    + COALESCE(o.product_platform_fees, 0)                                   AS platform_fees,
  COALESCE(b.booking_isr, 0)                                                 AS isr_withheld,
  COALESCE(b.booking_iva, 0)                                                 AS iva_withheld,
  COALESCE(b.booking_provider_net, 0)                                         AS provider_payouts
FROM booking_monthly b
FULL OUTER JOIN order_monthly o ON b.yr = o.yr AND b.mo = o.mo
ORDER BY 1 DESC, 2 DESC;

COMMENT ON VIEW public.v_monthly_revenue IS 'Monthly revenue summary combining booking and product order revenue. Service-role only.';


-- ---------------------------------------------------------------------------
-- 3. v_business_revenue — Revenue per business (all-time + current month)
-- ---------------------------------------------------------------------------
-- Joins businesses with aggregated appointment and order totals.
-- Current month is determined by America/Mexico_City timezone.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_business_revenue AS
WITH now_mx AS (
  SELECT
    EXTRACT(YEAR  FROM now() AT TIME ZONE 'America/Mexico_City')::int AS yr,
    EXTRACT(MONTH FROM now() AT TIME ZONE 'America/Mexico_City')::int AS mo
),
booking_totals AS (
  SELECT
    a.business_id,
    COUNT(*)                             AS total_bookings,
    COALESCE(SUM(a.price), 0)            AS total_revenue,
    COALESCE(SUM(a.platform_fee), 0)     AS total_platform_fees,
    COALESCE(SUM(a.isr_withheld), 0)     AS total_isr,
    COALESCE(SUM(a.iva_withheld), 0)     AS total_iva,
    -- Current month slice
    COUNT(*) FILTER (
      WHERE EXTRACT(YEAR  FROM a.paid_at AT TIME ZONE 'America/Mexico_City') = (SELECT yr FROM now_mx)
        AND EXTRACT(MONTH FROM a.paid_at AT TIME ZONE 'America/Mexico_City') = (SELECT mo FROM now_mx)
    )                                                                         AS current_month_bookings,
    COALESCE(SUM(a.price) FILTER (
      WHERE EXTRACT(YEAR  FROM a.paid_at AT TIME ZONE 'America/Mexico_City') = (SELECT yr FROM now_mx)
        AND EXTRACT(MONTH FROM a.paid_at AT TIME ZONE 'America/Mexico_City') = (SELECT mo FROM now_mx)
    ), 0)                                                                     AS current_month_revenue
  FROM public.appointments a
  WHERE a.payment_status = 'paid'
    AND a.paid_at IS NOT NULL
  GROUP BY a.business_id
),
order_totals AS (
  SELECT
    o.business_id,
    COALESCE(SUM(o.total_amount), 0)      AS total_product_revenue,
    COALESCE(SUM(o.commission_amount), 0)  AS total_product_fees,
    COALESCE(SUM(o.total_amount) FILTER (
      WHERE EXTRACT(YEAR  FROM o.created_at AT TIME ZONE 'America/Mexico_City') = (SELECT yr FROM now_mx)
        AND EXTRACT(MONTH FROM o.created_at AT TIME ZONE 'America/Mexico_City') = (SELECT mo FROM now_mx)
    ), 0)                                                                      AS current_month_product_revenue
  FROM public.orders o
  WHERE o.status NOT IN ('refunded', 'cancelled')
  GROUP BY o.business_id
)
SELECT
  biz.id                                                                       AS business_id,
  biz.name                                                                     AS business_name,
  biz.rfc,
  COALESCE(bt.total_bookings, 0)                                               AS total_bookings,
  COALESCE(bt.total_revenue, 0)
    + COALESCE(ot.total_product_revenue, 0)                                    AS total_revenue,
  COALESCE(bt.total_platform_fees, 0)
    + COALESCE(ot.total_product_fees, 0)                                       AS total_platform_fees,
  COALESCE(bt.total_isr, 0)                                                    AS total_isr,
  COALESCE(bt.total_iva, 0)                                                    AS total_iva,
  COALESCE(bt.current_month_revenue, 0)
    + COALESCE(ot.current_month_product_revenue, 0)                            AS current_month_revenue,
  COALESCE(bt.current_month_bookings, 0)                                       AS current_month_bookings
FROM public.businesses biz
LEFT JOIN booking_totals bt ON bt.business_id = biz.id
LEFT JOIN order_totals   ot ON ot.business_id = biz.id
WHERE biz.is_active = true
ORDER BY current_month_revenue DESC;

COMMENT ON VIEW public.v_business_revenue IS 'Per-business revenue totals (all-time and current month). Service-role only.';


-- ---------------------------------------------------------------------------
-- 4. v_payment_reconciliation — Payment-level detail for reconciliation
-- ---------------------------------------------------------------------------
-- Each paid appointment with its tax breakdown, linked payment info, and business.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_payment_reconciliation AS
SELECT
  (a.paid_at AT TIME ZONE 'America/Mexico_City')::date    AS payment_date,
  a.id                                                     AS appointment_id,
  biz.name                                                 AS business_name,
  a.service_name,
  COALESCE(a.price, 0)                                     AS gross_amount,
  COALESCE(a.platform_fee, 0)                              AS platform_fee,
  COALESCE(a.isr_withheld, 0)                              AS isr_withheld,
  COALESCE(a.iva_withheld, 0)                              AS iva_withheld,
  COALESCE(a.provider_net, 0)                               AS provider_net,
  p.payment_method,
  a.payment_status,
  a.payment_intent_id                                      AS stripe_payment_intent_id
FROM public.appointments a
JOIN public.businesses biz ON biz.id = a.business_id
LEFT JOIN LATERAL (
  SELECT pm.payment_method
  FROM public.payments pm
  WHERE pm.appointment_id = a.id
    AND pm.status = 'succeeded'
  ORDER BY pm.created_at DESC
  LIMIT 1
) p ON true
WHERE a.payment_status = 'paid'
  AND a.paid_at IS NOT NULL
ORDER BY a.paid_at DESC;

COMMENT ON VIEW public.v_payment_reconciliation IS 'Payment-level detail with tax breakdown for financial reconciliation. Service-role only.';


-- ---------------------------------------------------------------------------
-- 5. v_outstanding_payouts — Confirmed/completed but not yet paid out
-- ---------------------------------------------------------------------------
-- Appointments that are confirmed or completed but payment_status is not 'paid'.
-- days_outstanding = days since the appointment was scheduled.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_outstanding_payouts AS
SELECT
  a.id                                                                         AS appointment_id,
  biz.name                                                                     AS business_name,
  a.starts_at                                                                  AS scheduled_at,
  COALESCE(a.price, 0)                                                         AS price,
  a.payment_status,
  GREATEST(
    EXTRACT(DAY FROM now() - a.starts_at)::int,
    0
  )                                                                            AS days_outstanding
FROM public.appointments a
JOIN public.businesses biz ON biz.id = a.business_id
WHERE a.status IN ('confirmed', 'completed')
  AND a.payment_status NOT IN ('paid', 'refunded')
ORDER BY a.starts_at ASC;

COMMENT ON VIEW public.v_outstanding_payouts IS 'Appointments confirmed/completed but not yet paid. Tracks days outstanding. Service-role only.';


-- ---------------------------------------------------------------------------
-- 6. v_platform_health — Single-row key metrics for CEO dashboard
-- ---------------------------------------------------------------------------
-- Current platform snapshot: users, businesses, MTD revenue, today stats.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_platform_health AS
WITH now_mx AS (
  SELECT
    (now() AT TIME ZONE 'America/Mexico_City')::date                           AS today,
    EXTRACT(YEAR  FROM now() AT TIME ZONE 'America/Mexico_City')::int          AS yr,
    EXTRACT(MONTH FROM now() AT TIME ZONE 'America/Mexico_City')::int          AS mo
),
users_count AS (
  SELECT COUNT(*) AS total_users
  FROM public.profiles
),
biz_count AS (
  SELECT COUNT(*) AS total_businesses
  FROM public.businesses
  WHERE is_active = true
),
bookings_mtd AS (
  SELECT
    COUNT(*)                             AS total_bookings_mtd,
    COALESCE(SUM(a.price), 0)            AS total_revenue_mtd,
    COALESCE(SUM(a.platform_fee), 0)     AS total_platform_fees_mtd,
    COALESCE(SUM(a.isr_withheld), 0)     AS total_isr_mtd,
    COALESCE(SUM(a.iva_withheld), 0)     AS total_iva_mtd,
    COALESCE(AVG(a.price), 0)            AS avg_booking_value
  FROM public.appointments a
  CROSS JOIN now_mx n
  WHERE a.payment_status = 'paid'
    AND a.paid_at IS NOT NULL
    AND EXTRACT(YEAR  FROM a.paid_at AT TIME ZONE 'America/Mexico_City') = n.yr
    AND EXTRACT(MONTH FROM a.paid_at AT TIME ZONE 'America/Mexico_City') = n.mo
),
bookings_today AS (
  SELECT
    COUNT(*)                    AS bookings_today,
    COALESCE(SUM(a.price), 0)   AS revenue_today
  FROM public.appointments a
  CROSS JOIN now_mx n
  WHERE a.payment_status = 'paid'
    AND a.paid_at IS NOT NULL
    AND (a.paid_at AT TIME ZONE 'America/Mexico_City')::date = n.today
)
SELECT
  uc.total_users,
  bc.total_businesses,
  COALESCE(bm.total_bookings_mtd, 0)      AS total_bookings_mtd,
  COALESCE(bm.total_revenue_mtd, 0)       AS total_revenue_mtd,
  COALESCE(bm.total_platform_fees_mtd, 0) AS total_platform_fees_mtd,
  COALESCE(bm.total_isr_mtd, 0)           AS total_isr_mtd,
  COALESCE(bm.total_iva_mtd, 0)           AS total_iva_mtd,
  ROUND(COALESCE(bm.avg_booking_value, 0), 2) AS avg_booking_value,
  COALESCE(bt.bookings_today, 0)           AS bookings_today,
  COALESCE(bt.revenue_today, 0)            AS revenue_today
FROM users_count uc
CROSS JOIN biz_count bc
CROSS JOIN bookings_mtd bm
CROSS JOIN bookings_today bt;

COMMENT ON VIEW public.v_platform_health IS 'Single-row platform health snapshot for CEO dashboard. Service-role only.';
