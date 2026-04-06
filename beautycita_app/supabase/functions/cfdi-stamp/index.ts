// =============================================================================
// cfdi-stamp — Issue CFDI retenciones and invoices via SW Sapien PAC
// =============================================================================
// Called after a BC-marketplace booking completes to generate the withholding
// certificate (Comprobante de Retenciones) that BC is required to issue as a
// digital platform intermediary under LISR Art. 113-A / LIVA Art. 18-J.
//
// Walk-in bookings (booking_source = 'walk_in') NEVER trigger this function.
// Only bookings where BC processed the payment as intermediary get CFDIs.
//
// POST body: { appointment_id: string }
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// SW Sapien PAC credentials
// TODO: Replace with production credentials when SW Sapien account is active
const SW_URL = Deno.env.get("SW_SAPIEN_URL") ?? "https://services.test.sw.com.mx";
const SW_USER = Deno.env.get("SW_SAPIEN_USER") ?? "demo";
const SW_PASSWORD = Deno.env.get("SW_SAPIEN_PASSWORD") ?? "123456789";

// BC's RFC and fiscal info (issuer of retenciones)
const BC_RFC = Deno.env.get("BC_RFC") ?? "EKU9003173C9"; // Test RFC — replace with BC's real RFC
const BC_NOMBRE = "BeautyCita S.A. de C.V.";
const BC_REGIMEN_FISCAL = "601"; // General de Ley Personas Morales
const BC_LUGAR_EXPEDICION = "48315"; // Puerto Vallarta CP

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "https://beautycita.com",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

// ── SW Sapien Authentication ─────────────────────────────────────────────────

let _swToken: string | null = null;
let _swTokenExpiry = 0;

async function getSwToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (_swToken && _swTokenExpiry > now + 300) {
    return _swToken; // reuse if >5min remaining
  }

  const res = await fetch(`${SW_URL}/v2/security/authenticate`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user: SW_USER, password: SW_PASSWORD }),
  });

  const data = await res.json();
  if (data.status !== "success" || !data.data?.token) {
    throw new Error(`SW auth failed: ${data.message ?? "unknown error"}`);
  }

  _swToken = data.data.token;
  _swTokenExpiry = data.data.expires_in;
  console.log("[CFDI] SW token obtained, expires:", new Date(_swTokenExpiry * 1000).toISOString());
  return _swToken!;
}

// ── CFDI JSON Builder ────────────────────────────────────────────────────────

interface BookingData {
  id: string;
  business_id: string;
  service_name: string;
  price: number;
  tax_base: number;
  isr_withheld: number;
  iva_withheld: number;
  provider_net: number;
  booking_source: string;
  starts_at: string;
  business_rfc: string | null;
  business_name: string;
  business_regimen: string | null;
  business_cp: string | null;
}

function buildRetencionesJson(booking: BookingData): Record<string, unknown> {
  // CFDI de Retenciones e Información de Pagos
  // Schema: http://www.sat.gob.mx/esquemas/retencionpago/2
  const now = new Date();
  const fecha = now.toISOString().replace(/\.\d{3}Z$/, "");

  return {
    // Comprobante attributes
    Version: "2.0",
    FolioInt: booking.id.substring(0, 20),
    FechaExp: fecha,
    CveRetenc: "26", // 26 = Servicios de plataformas tecnológicas
    LugarExpRetworking: BC_LUGAR_EXPEDICION,

    // Emisor (BC — the platform issuing the retention)
    Emisor: {
      RfcE: BC_RFC,
      NomDenRazSocE: BC_NOMBRE,
      RegimenFiscalE: BC_REGIMEN_FISCAL,
    },

    // Receptor (the salon receiving the retention certificate)
    Receptor: {
      NacionalidadR: "Nacional",
      Nacional: {
        RfcR: booking.business_rfc ?? "XAXX010101000", // RFC genérico if salon has no RFC
        NomDenRazSocR: booking.business_name,
        DomicilioFiscalR: booking.business_cp ?? "48315",
      },
    },

    // Periodo (month of the transaction)
    Periodo: {
      MesIni: (now.getMonth() + 1).toString().padStart(2, "0"),
      MesFin: (now.getMonth() + 1).toString().padStart(2, "0"),
      Ejercicio: now.getFullYear().toString(),
    },

    // Totales
    Totales: {
      MontoTotOperacion: booking.price.toFixed(2),
      MontoTotGrav: booking.tax_base.toFixed(2),
      MontoTotExent: "0.00",
      MontoTotRet: (booking.isr_withheld + booking.iva_withheld).toFixed(2),
      ImpRetenidos: [
        {
          BaseRet: booking.tax_base.toFixed(2),
          ImpuestoRet: "001", // ISR
          MontoRet: booking.isr_withheld.toFixed(2),
          TipoPagoRet: "03", // Pago provisional
        },
        {
          BaseRet: booking.tax_base.toFixed(2),
          ImpuestoRet: "002", // IVA
          MontoRet: booking.iva_withheld.toFixed(2),
          TipoPagoRet: "03",
        },
      ],
    },

    // Complemento: Servicios Plataformas Tecnológicas
    Complemento: {
      ServiciosPlataformasTecnologicas: {
        Version: "1.0",
        Periodicidad: "05", // Mensual — TODO: batch monthly
        NumServ: 1,
        MonTotServSIVA: booking.tax_base.toFixed(2),
        TotalIVATrasladado: (booking.tax_base * 0.16).toFixed(2),
        TotalIVARetenido: booking.iva_withheld.toFixed(2),
        TotalISRRetenido: booking.isr_withheld.toFixed(2),
        DifIVAEnt662: "0.00",
        DetallesDelServicio: {
          FormaPagoServ: "03", // Transferencia electrónica
          TipoDeServ: "01", // Prestación de servicios
          SubTipServ: "01", // General
          RFCTerceroAutorizado: booking.business_rfc ?? "XAXX010101000",
          FechaServ: booking.starts_at.substring(0, 10),
          PrecioServSinIVA: booking.tax_base.toFixed(2),
        },
        ComisionDelServicio: {
          Base: booking.price.toFixed(2),
          Porcentaje: "3.00",
          Importe: (booking.price * 0.03).toFixed(2),
        },
      },
    },
  };
}

function buildIngresoJson(booking: BookingData): Record<string, unknown> {
  // Standard CFDI de Ingreso for BC's 3% commission invoice
  const now = new Date();
  const fecha = now.toISOString().replace(/\.\d{3}Z$/, "");
  const commission = booking.price * 0.03;
  const commissionBase = commission / 1.16;
  const commissionIva = commission - commissionBase;

  return {
    Version: "4.0",
    Serie: "COM",
    Folio: booking.id.substring(0, 20),
    Fecha: fecha,
    FormaPago: "03", // Transferencia
    MetodoPago: "PUE", // Pago en una sola exhibición
    TipoDeComprobante: "I", // Ingreso
    LugarExpedicion: BC_LUGAR_EXPEDICION,
    Moneda: "MXN",
    SubTotal: commissionBase.toFixed(2),
    Total: commission.toFixed(2),

    Emisor: {
      Rfc: BC_RFC,
      Nombre: BC_NOMBRE,
      RegimenFiscal: BC_REGIMEN_FISCAL,
    },

    Receptor: {
      Rfc: booking.business_rfc ?? "XAXX010101000",
      Nombre: booking.business_name,
      DomicilioFiscalReceptor: booking.business_cp ?? "48315",
      RegimenFiscalReceptor: booking.business_regimen ?? "612", // Personas Físicas con Actividad Empresarial
      UsoCFDI: "G03", // Gastos en general
    },

    Conceptos: [
      {
        ClaveProdServ: "80141600", // Servicios de gestión de eventos
        Cantidad: "1",
        ClaveUnidad: "E48", // Servicio
        Unidad: "Servicio",
        Descripcion: `Comision por servicio de intermediacion - ${booking.service_name}`,
        ValorUnitario: commissionBase.toFixed(2),
        Importe: commissionBase.toFixed(2),
        ObjetoImp: "02", // Si objeto de impuesto
        Impuestos: {
          Traslados: [
            {
              Base: commissionBase.toFixed(2),
              Impuesto: "002", // IVA
              TipoFactor: "Tasa",
              TasaOCuota: "0.160000",
              Importe: commissionIva.toFixed(2),
            },
          ],
        },
      },
    ],

    Impuestos: {
      TotalImpuestosTrasladados: commissionIva.toFixed(2),
      Traslados: [
        {
          Base: commissionBase.toFixed(2),
          Impuesto: "002",
          TipoFactor: "Tasa",
          TasaOCuota: "0.160000",
          Importe: commissionIva.toFixed(2),
        },
      ],
    },
  };
}

// ── Stamp via SW Sapien ──────────────────────────────────────────────────────

async function stampCfdi(cfdiJson: Record<string, unknown>, isRetenciones: boolean): Promise<{
  success: boolean;
  uuid?: string;
  xml?: string;
  error?: string;
}> {
  const token = await getSwToken();
  const endpoint = isRetenciones
    ? `${SW_URL}/v4/cfdi33/issue/json/v4` // Retenciones use same issue endpoint
    : `${SW_URL}/v4/cfdi33/issue/json/v4`;

  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(cfdiJson),
  });

  const data = await res.json();

  if (data.status === "success" && data.data) {
    return {
      success: true,
      uuid: data.data.uuid,
      xml: data.data.cfdi, // The stamped XML
    };
  }

  return {
    success: false,
    error: `${data.message ?? "Unknown"}: ${data.messageDetail ?? ""}`,
  };
}

// ── Main Handler ─────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // Auth check
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");
  if (!token) return json({ error: "Authorization required" }, 401);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  try {
    const { appointment_id } = await req.json();
    if (!appointment_id) return json({ error: "appointment_id required" }, 400);

    // 1. Fetch appointment with business data
    const { data: appt, error: apptErr } = await supabase
      .from("appointments")
      .select(`
        id, business_id, service_name, price, tax_base,
        isr_withheld, iva_withheld, provider_net, booking_source, starts_at,
        businesses!appointments_business_id_fkey (
          name, rfc, tax_regime, city, state
        )
      `)
      .eq("id", appointment_id)
      .single();

    if (apptErr || !appt) {
      return json({ error: "Appointment not found" }, 404);
    }

    // 2. Guard: only BC-intermediary bookings get CFDIs
    if (appt.booking_source === "walk_in") {
      return json({ error: "Walk-in bookings do not generate CFDIs" }, 400);
    }

    // 3. Guard: must have tax data
    if (!appt.tax_base || !appt.isr_withheld) {
      return json({ error: "Appointment missing tax withholding data" }, 400);
    }

    // 4. Check if CFDI already exists for this appointment
    const { data: existing } = await supabase
      .from("cfdi_records")
      .select("id, uuid")
      .eq("appointment_id", appointment_id)
      .maybeSingle();

    if (existing) {
      return json({ error: "CFDI already exists", uuid: existing.uuid }, 409);
    }

    const biz = (appt as any).businesses;
    const bookingData: BookingData = {
      id: appt.id,
      business_id: appt.business_id,
      service_name: appt.service_name,
      price: appt.price,
      tax_base: appt.tax_base,
      isr_withheld: appt.isr_withheld,
      iva_withheld: appt.iva_withheld,
      provider_net: appt.provider_net,
      booking_source: appt.booking_source,
      starts_at: appt.starts_at,
      business_rfc: biz?.rfc ?? null,
      business_name: biz?.name ?? "Salon",
      business_regimen: biz?.tax_regime ?? null,
      business_cp: null, // TODO: add CP to businesses table
    };

    // 5. Build and stamp the retenciones CFDI
    console.log(`[CFDI] Stamping retenciones for appointment ${appointment_id}`);
    const retencionesJson = buildRetencionesJson(bookingData);
    const retencionesResult = await stampCfdi(retencionesJson, true);

    if (!retencionesResult.success) {
      console.error(`[CFDI] Retenciones stamp failed: ${retencionesResult.error}`);
      // Don't block — log the failure for manual reconciliation
      await supabase.from("user_error_reports").insert({
        source: "cfdi-stamp",
        error_type: "stamp_failed",
        error_message: retencionesResult.error,
        metadata: { appointment_id, type: "retenciones" },
      }).then(() => {}).catch(() => {});

      return json({
        success: false,
        error: retencionesResult.error,
        appointment_id,
      }, 500);
    }

    // 6. Store CFDI record
    await supabase.from("cfdi_records").insert({
      appointment_id,
      business_id: appt.business_id,
      uuid: retencionesResult.uuid,
      xml: retencionesResult.xml,
      type: "retenciones",
      status: "stamped",
      gross_amount: appt.price,
      isr_withheld: appt.isr_withheld,
      iva_withheld: appt.iva_withheld,
      provider_net: appt.provider_net,
    });

    console.log(`[CFDI] Stamped retenciones ${retencionesResult.uuid} for appointment ${appointment_id}`);

    // 7. Optionally stamp the commission invoice (BC's 3% fee)
    // This is BC billing the salon, separate from the retenciones
    let commissionUuid: string | null = null;
    try {
      const commissionJson = buildIngresoJson(bookingData);
      const commissionResult = await stampCfdi(commissionJson, false);
      if (commissionResult.success) {
        commissionUuid = commissionResult.uuid ?? null;
        await supabase.from("cfdi_records").insert({
          appointment_id,
          business_id: appt.business_id,
          uuid: commissionResult.uuid,
          xml: commissionResult.xml,
          type: "ingreso_comision",
          status: "stamped",
          gross_amount: appt.price * 0.03,
        });
        console.log(`[CFDI] Stamped commission invoice ${commissionResult.uuid}`);
      }
    } catch (e) {
      console.error(`[CFDI] Commission invoice failed (non-blocking):`, e);
    }

    return json({
      success: true,
      appointment_id,
      retenciones_uuid: retencionesResult.uuid,
      commission_uuid: commissionUuid,
    });

  } catch (err) {
    console.error("[CFDI] Handler error:", (err as Error).message);
    return json({ error: "Internal server error" }, 500);
  }
});
