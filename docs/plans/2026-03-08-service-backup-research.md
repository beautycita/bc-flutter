# Service Backup / Alternative Provider Research

> **Date:** 2026-03-08
> **Purpose:** Research-only. Identify drop-in alternatives for critical third-party services.
> **Status:** Not for immediate implementation — contingency planning.

---

## 1. Payment Processing (Stripe Replacement)

### Current Setup (Stripe)
- Stripe Connect Express (marketplace model)
- 3.6% + $3 MXN per card/OXXO transaction
- Card + OXXO payment methods
- MXN currency, Mexico-based
- Mobile: PaymentSheet + ephemeral keys (official `flutter_stripe`)
- BTCPay Server for Bitcoin (self-hosted, already a backup for fiat)

### RECOMMENDATION: Stay with Stripe

**No alternative fully matches Stripe Connect Express** for BeautyCita's marketplace architecture. Here's the competitive landscape:

| Processor | Marketplace Splits | OXXO | SPEI | Flutter SDK | Card Pricing |
|-----------|-------------------|------|------|-------------|-------------|
| **Stripe** (current) | Connect Express | Yes | Yes (Citibanamex) | Official `flutter_stripe` | 3.6% + $3 MXN |
| **MercadoPago** | Yes (OAuth splits) | Yes | Yes | Community only | 3.49% + $4 MXN |
| **Adyen** | Yes (for Platforms) | Yes | Yes | Official `adyen_checkout` | ~2.5-3.5% (interchange++) |
| **Conekta** | No (manual payouts) | Yes | Yes (1%!) | Basic `conekta` pkg | 3.6% + $3 MXN |
| **OpenPay** | No | Yes | Yes | None | 2.9% + $2.5 MXN |
| **PayPal** | Yes (Multiparty) | **No** | Withdrawals only | None | 3.49% + $0.49 USD |

**Why Stripe wins:**
1. Only processor with mature marketplace onboarding + split payments + quality Flutter SDK
2. Already integrated — migration cost to any alternative is weeks of work
3. Supports all 3 key Mexico payment methods (cards, OXXO, SPEI)

**If Stripe became unavailable, ranked alternatives:**
1. **MercadoPago** — closest functional equivalent, native marketplace splits via OAuth, but community Flutter SDK
2. **Adyen** — best tech + official Flutter SDK, but enterprise-gated (minimum volume requirements)
3. **Conekta** — best SPEI pricing (1%), native Mexican, but no marketplace model (you'd build your own split logic)

**Optimization opportunity:** Add **Conekta as secondary processor for SPEI-only payments** at 1% vs Stripe's ~3.6%. Route SPEI through Conekta, keep everything else on Stripe.

### Bank Transfer (SPEI)
- Stripe already supports SPEI via their bank transfer product (Citibanamex as SPEI member)
- Generates CLABE reference, confirmation within ~30 minutes on business days
- Requires Mexican legal entity (BeautyCita S.A. de C.V. qualifies)
- **Action:** Enable SPEI in Stripe dashboard — no provider switch needed
- **CoDi/DiMo:** Skip. CoDi was a commercial failure (1.9M users in 4 years). Banxico pivoting to DiMo. No processor has meaningful integration.

---

## 2. SMS / Communications (Twilio Replacement)

### Current Setup
- Firebase Cloud Messaging for push notifications (NOT Twilio)
- WhatsApp used manually for salon onboarding
- No programmatic SMS currently

### RECOMMENDATION: Infobip

**Why Infobip:**
- **Mexico-first strategy** — local teams, Spanish-speaking support, direct Telcel/Movistar/AT&T Mexico carrier connections
- **Premier Meta Partner for WhatsApp** — fastest onboarding, early feature access
- **Official Flutter plugin** — `infobip_mobilemessaging` on pub.dev (only provider with one)
- **Single platform** — SMS + WhatsApp + push + RCS + email + voice
- **A2P compliance assistance** — help with IFT/REPEP registration, Telcel pre-registration

**Pricing:**
- SMS Mexico: ~$0.005-0.01/message
- WhatsApp utility: ~$0.008-0.015/msg (free during active 24h service window)
- WhatsApp auth: ~$0.006-0.01/msg

**Runners-up:**
- **Plivo** — cheapest SMS at $0.004/msg, but no LATAM specialization, no Flutter SDK
- **Meta WhatsApp direct** — zero markup but you manage everything yourself

**Mexico SMS compliance notes:**
- Pre-registration required with Telcel/Movistar (2-4 weeks, $100-500 setup)
- REPEP do-not-call registry compliance mandatory
- No messaging 9 PM - 9 AM except critical alerts/auth

---

## 3. Image Processing (LightX Replacement)

### Current Setup
- LightX v2 API for Virtual Studio (4 tools):
  1. Background removal/replacement
  2. AI hair color change
  3. AI style transfer
  4. Image enhancement/retouching

### RECOMMENDATION: Picsart API

**Why Picsart:**
- **Only alternative covering ALL 4 LightX use cases** in a single API
- **Purpose-built beauty/face editing** — hair color change is texture-aware, face enhancement handles retouching natively
- Background removal v10 model is top-tier
- Style transfer via AI Providers Hub (20+ models)
- Pricing starts at $0.01/image
- Single vendor, single integration

**Migration path:** Replace LightX API calls 1:1 with Picsart equivalents. ~1-2 days effort.

**Runners-up:**
- **Replicate** — most flexible (run any open-source model), but requires ML engineering for model selection/tuning, cold start latency concerns
- **Self-hosted ComfyUI** — zero per-image cost at scale (1000+/day), but massive ops overhead. Not worth it at current stage.

---

## 4. LLM / AI Chat (OpenAI Replacement)

### Current Setup
- OpenAI (likely GPT-4o) for:
  - AI chat personas (Aphrodite, Eros)
  - Business copy generation
  - Future AI features

### RECOMMENDATION: Anthropic Claude API (Sonnet 4.6)

**Why Claude:**
- **Superior persona consistency** — excels at maintaining character personalities with complex system prompts
- **Prompt caching** — 90% input cost reduction on repeated system prompts (perfect for chat personas that reuse the same system prompt across all users)
- **Spanish quality** — handles Mexican Spanish colloquialisms, humor, tone naturally
- **Tiered models** — Haiku ($0.25/$1.25) for simple copy, Sonnet ($3/$15) for chat, Opus ($5/$25) if needed
- 200K context window

**Pricing comparison:**
| Model | Input/1M | Output/1M |
|-------|----------|-----------|
| GPT-4o (current) | $2.50 | $10.00 |
| Claude Sonnet 4.6 | $3.00 | $15.00 |
| Claude Haiku 3 | $0.25 | $1.25 |
| With prompt caching | ~$0.30 effective | $15.00 |

**Migration effort:** ~2-4 hours. Different API format (Messages API vs Chat Completions) but system prompt approach maps directly.

**Runners-up:**
- **Mistral AI** — OpenAI-compatible API (near-zero migration), cheap small models ($0.06/$0.18 for Small 3.2), but weaker Spanish persona quality
- **Google Gemini Flash-Lite** — $0.10/$0.40, 25x cheaper than GPT-4o. "Good enough" quality for budget scenarios.

---

## Summary

| Service | Current | Recommended Backup | Migration Effort | Monthly Cost |
|---------|---------|-------------------|-----------------|-------------|
| Payments | Stripe | **Stay with Stripe** (MercadoPago if forced) | Very High | 3.49% + $4 MXN |
| Bank Transfer | N/A | SPEI via Stripe (or Conekta at 1%) | Low (config) | 1-3.6% |
| SMS/WhatsApp | None | **Infobip** | Medium (new) | ~$20-50 |
| Image Processing | LightX | **Picsart API** | Medium (1-2 days) | ~$20-50 |
| LLM / AI | OpenAI | **Claude Sonnet 4.6** | Low (2-4 hours) | ~$15-40 |
| Bitcoin | BTCPay | Already self-hosted | N/A | $0 |
