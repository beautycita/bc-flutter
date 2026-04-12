// =============================================================================
// Mexican Tax Withholding Calculator (ISR + IVA)
// =============================================================================
// Per LISR Art. 113-A and LIVA Art. 18-J, digital intermediation platforms
// must withhold ISR (income tax) and IVA (value-added tax) from provider
// payments and remit to SAT.
//
// Rates (beauty services — "servicios de belleza"):
//   With RFC:    ISR 2.5% of gross, IVA 8% (50% of 16%)
//   Without RFC: ISR 20% of gross,  IVA 16% (100%)
//   Foreign:     Same as without RFC
//   PF and PM:   Same rates (confirmed by attorney 2026-03-13)
//
// Mexican prices are IVA-inclusive: base = price / 1.16
//
// COUNTRY EXTENSIBILITY:
// This module handles Mexico (MX) only. To add another country:
//   1. Create a new file: tax_{country_code}.ts (e.g., tax_co.ts for Colombia)
//   2. Export the same { calculateWithholding, TaxWithholding } interface
//   3. In the calling edge function, route by business.tax_residency to the
//      correct country module: 'MX' → tax_mx.ts, 'CO' → tax_co.ts, etc.
//   4. The TaxWithholding interface is country-agnostic — all countries return
//      the same structure (grossAmount, taxBase, rates, withheld, providerNet).
// =============================================================================

/** Tax withholding breakdown for a single transaction. */
export interface TaxWithholding {
  /** ISO 3166-1 alpha-2 country code for the tax jurisdiction */
  jurisdiction: string;
  /** Total amount charged to customer (IVA-inclusive) */
  grossAmount: number;
  /** Pre-IVA base: gross / 1.16 */
  taxBase: number;
  /** IVA portion of the price: gross - taxBase */
  ivaPortion: number;
  /** Platform commission (3% of gross) */
  platformFee: number;
  /** ISR rate applied (0.025 or 0.20) */
  isrRate: number;
  /** IVA withholding rate applied (0.08 or 0.16) */
  ivaRate: number;
  /** ISR withheld: grossAmount * isrRate */
  isrWithheld: number;
  /** IVA withheld: ivaPortion * ivaRate */
  ivaWithheld: number;
  /** Net amount provider receives: gross - platformFee - isrWithheld - ivaWithheld */
  providerNet: number;
}

/**
 * Calculate Mexican ISR/IVA withholdings for a provider payment.
 *
 * @param grossAmount     Total charged to the customer (MXN, IVA-inclusive)
 * @param platformFeeRate Platform fee as decimal (e.g. 0.03 for 3%)
 * @param providerRfc     Provider's RFC, or null/empty if not registered
 * @param taxResidency    'MX' for Mexican fiscal resident, 'foreign' otherwise
 * @returns Full withholding breakdown
 */
export function calculateWithholding(
  grossAmount: number,
  platformFeeRate: number,
  providerRfc: string | null | undefined,
  taxResidency: string = "MX",
): TaxWithholding {
  // Mexican prices include 16% IVA
  const taxBase = round2(grossAmount / 1.16);
  const ivaPortion = round2(grossAmount - taxBase);

  // Platform fee on gross amount
  const platformFee = round2(grossAmount * platformFeeRate);

  // Determine rates based on RFC status and residency
  const hasRfc = !!providerRfc && providerRfc.trim().length >= 12;
  const isMexican = taxResidency === "MX";

  let isrRate: number;
  let ivaRate: number;

  if (hasRfc && isMexican) {
    // Registered Mexican provider: reduced rates
    isrRate = 0.025; // 2.5%
    ivaRate = 0.08;  // 8% (50% of 16%)
  } else {
    // No RFC or foreign: maximum withholding
    isrRate = 0.20;  // 20%
    ivaRate = 0.16;  // 16% (100%)
  }

  // ISR is withheld on gross amount
  const isrWithheld = round2(grossAmount * isrRate);
  // IVA is withheld on the IVA portion
  const ivaWithheld = round2(ivaPortion * ivaRate);

  // Provider receives what's left (clamped to 0 — never go negative)
  const rawNet = grossAmount - platformFee - isrWithheld - ivaWithheld;
  const providerNet = Math.max(round2(rawNet), 0);

  return {
    jurisdiction: "MX",
    grossAmount,
    taxBase,
    ivaPortion,
    platformFee,
    isrRate,
    ivaRate,
    isrWithheld,
    ivaWithheld,
    providerNet,
  };
}

/** Round to 2 decimal places (MXN centavos). */
function round2(n: number): number {
  return Math.round(n * 100) / 100;
}
