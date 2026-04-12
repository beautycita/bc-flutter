# E2E Manual QA Test Plan

Prerequisite: Test salon active with services, staff, and Stripe connected.
BC's wife has $5K saldo. Test user has card saved.

## 1. Booking with Saldo

- [ ] Open app as test user with saldo balance
- [ ] Select service category → subcategory → service
- [ ] Verify top 3 results appear within 2 seconds
- [ ] Select a result → confirmation screen
- [ ] Select "Saldo" as payment method
- [ ] Verify tax breakdown shows: ISR 2.5%, IVA 8% (if salon has RFC)
- [ ] Confirm booking → "Reservado" screen
- [ ] Verify saldo deducted in profile (exact amount matches price)
- [ ] Verify booking appears in "Mis Citas" → upcoming tab
- [ ] Verify appointment record in DB has: payment_status=paid, payment_method=saldo, isr_withheld/iva_withheld/provider_net populated
- [ ] Verify tax_withholdings ledger row created
- [ ] Verify commission_records row created (if marketplace source)

## 2. Booking with Stripe Card

- [ ] Open app, select service, get results
- [ ] Select "Tarjeta" as payment method
- [ ] Confirm booking → Stripe payment sheet appears
- [ ] Complete card payment
- [ ] Verify booking status transitions: pending → confirmed (after webhook)
- [ ] Verify payment_status: pending → paid
- [ ] Verify Stripe dashboard shows payment with application_fee
- [ ] Verify tax_withholdings and commission_records created

## 3. Cancellation — Free Window

- [ ] Create a booking scheduled >24hrs from now (within free cancel window)
- [ ] Go to Mis Citas → tap booking → Cancel
- [ ] Verify shredder animation plays
- [ ] Verify refund amount shown: price minus 3% commission (marketplace) or full (salon_direct)
- [ ] Verify saldo credited with refund amount
- [ ] Verify booking status: cancelled_customer
- [ ] Verify payment_status: refunded_to_saldo
- [ ] Verify commission_records row for cancellation commission

## 4. Cancellation — Late (Deposit Forfeited)

- [ ] Create a booking at a salon with deposit policy (20%, cancellation_hours=24)
- [ ] Wait until within the cancellation window (<24hrs to appointment)
- [ ] Cancel the booking
- [ ] Verify deposit forfeited amount shown
- [ ] Verify refund = price - deposit - commission
- [ ] Verify payment_status: deposit_forfeited

## 5. Product Purchase with Saldo

- [ ] Navigate to a salon's storefront or POS
- [ ] Select a product, tap "Comprar"
- [ ] Verify payment via saldo (no Stripe for saldo purchases)
- [ ] Verify saldo deducted by total_amount
- [ ] Verify order created with status=paid, payment_method=saldo
- [ ] Verify commission_records row: 10% commission, source=product_sale
- [ ] Verify business receives push notification for new order

## 6. Gift Card Redemption

- [ ] Create a gift card (from business panel or admin)
- [ ] As receiving user, enter gift card code
- [ ] Verify saldo credited with gift card amount
- [ ] Verify gift_cards record: status=redeemed, redeemed_by=user_id
- [ ] Book a service using the newly credited saldo (end-to-end)

## 7. Cita Express (Walk-in QR)

- [ ] Scan a salon's QR code (or open /cita-express/{businessId})
- [ ] Verify salon info loads, services listed
- [ ] Select a service → see available walk-in slots
- [ ] Select a slot → confirmation screen
- [ ] Verify payment method defaults to cash_direct
- [ ] Confirm → booking created
- [ ] Verify booking_source=cita_express, commission_rate=0%
- [ ] Verify tax withholdings still calculated (even for cash)

## 8. Idempotency Check

- [ ] Double-tap confirm button rapidly on booking confirmation
- [ ] Verify only one booking created (idempotency key prevents duplicate)
- [ ] Double-tap confirm on product purchase
- [ ] Verify only one order created (5-minute dedup window)

## Edge Cases

- [ ] Book with insufficient saldo → error "Saldo insuficiente"
- [ ] Book at inactive salon → error "salon no disponible"
- [ ] Cancel already-cancelled booking → no-op, no money moves
- [ ] Salon without RFC → ISR 20%, IVA 16% (verify higher withholding)
