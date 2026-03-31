// =============================================================================
// staff-monthly-report — Monthly email report for staff members (stylists)
// =============================================================================
// Sends each staff member a summary of their services, commissions, and
// payments for the previous month. Designed to run as a monthly cron job
// on the 1st of each month.
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

serve(async (_req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const now = new Date();
    // Report for previous month
    const reportMonth = now.getMonth() === 0 ? 12 : now.getMonth();
    const reportYear = now.getMonth() === 0 ? now.getFullYear() - 1 : now.getFullYear();

    const monthStart = `${reportYear}-${String(reportMonth).padStart(2, "0")}-01`;
    const monthEnd = reportMonth === 12
      ? `${reportYear + 1}-01-01`
      : `${reportYear}-${String(reportMonth + 1).padStart(2, "0")}-01`;

    const monthNames = [
      "", "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
      "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
    ];

    // Get all active staff with email
    const { data: staffList } = await supabase
      .from("staff")
      .select("id, first_name, last_name, email, business_id, position, commission_rate, businesses(name)")
      .eq("is_active", true)
      .not("email", "is", null);

    if (!staffList || staffList.length === 0) {
      return json({ message: "No staff with email to report", count: 0 });
    }

    let sent = 0;

    for (const staff of staffList) {
      const staffId = staff.id;
      const email = staff.email;
      if (!email) continue;

      const salonName = (staff as any).businesses?.name ?? "Tu salon";
      const fullName = `${staff.first_name} ${staff.last_name ?? ""}`.trim();

      // Get appointments for this staff in the report period
      const { data: appointments } = await supabase
        .from("appointments")
        .select("id, service_name, price, starts_at, status, payment_status, payment_method")
        .eq("staff_id", staffId)
        .gte("starts_at", monthStart)
        .lt("starts_at", monthEnd)
        .order("starts_at");

      const appts = appointments ?? [];

      // Get commissions
      const { data: commissions } = await supabase
        .from("staff_commissions")
        .select("amount, status, created_at")
        .eq("staff_id", staffId)
        .eq("period_year", reportYear)
        .eq("period_month", reportMonth);

      const comms = commissions ?? [];

      // Calculate totals
      const totalServices = appts.filter((a: any) => a.status === "completed").length;
      const totalRevenue = appts
        .filter((a: any) => a.status === "completed")
        .reduce((sum: number, a: any) => sum + (Number(a.price) || 0), 0);
      const commissionRate = Number(staff.commission_rate) || 0;
      const totalCommissions = comms.reduce((sum: number, c: any) => sum + (Number(c.amount) || 0), 0);
      const paidCommissions = comms
        .filter((c: any) => c.status === "paid")
        .reduce((sum: number, c: any) => sum + (Number(c.amount) || 0), 0);
      const pendingCommissions = totalCommissions - paidCommissions;
      const cancelledCount = appts.filter((a: any) =>
        a.status === "cancelled_customer" || a.status === "cancelled_business"
      ).length;
      const noShowCount = appts.filter((a: any) => a.status === "no_show").length;

      // Build service breakdown
      const serviceMap = new Map<string, { count: number; revenue: number }>();
      for (const a of appts.filter((a: any) => a.status === "completed")) {
        const name = (a as any).service_name ?? "Otro";
        const existing = serviceMap.get(name) ?? { count: 0, revenue: 0 };
        existing.count++;
        existing.revenue += Number((a as any).price) || 0;
        serviceMap.set(name, existing);
      }

      const serviceBreakdown = Array.from(serviceMap.entries())
        .map(([name, data]) => `  - ${name}: ${data.count} citas, $${data.revenue.toFixed(0)} MXN`)
        .join("\n");

      // Build email body
      const body = `Hola ${fullName},

Aqui esta tu reporte mensual de ${monthNames[reportMonth]} ${reportYear} en ${salonName}.

RESUMEN
-------
Servicios completados: ${totalServices}
Cancelaciones: ${cancelledCount}
No-shows: ${noShowCount}
Ingresos generados: $${totalRevenue.toFixed(0)} MXN

COMISIONES (${commissionRate}%)
-------
Total ganado: $${totalCommissions.toFixed(2)} MXN
Pagado: $${paidCommissions.toFixed(2)} MXN
Pendiente: $${pendingCommissions.toFixed(2)} MXN

DESGLOSE POR SERVICIO
-------
${serviceBreakdown || "  Sin servicios este mes"}

Este reporte es generado automaticamente por BeautyCita.
Si tienes preguntas, contacta a la recepcion de ${salonName}.

— BeautyCita
RFC: BEA260313MI8`;

      // Send email via send-email edge function
      try {
        await supabase.functions.invoke("send-email", {
          body: {
            to: email,
            subject: `Reporte ${monthNames[reportMonth]} ${reportYear} — ${salonName}`,
            text: body,
          },
        });
        sent++;
        console.log(`[STAFF-REPORT] Sent to ${email} (${fullName} at ${salonName})`);
      } catch (emailErr) {
        console.error(`[STAFF-REPORT] Failed to send to ${email}:`, emailErr);
      }
    }

    return json({ message: `Reports sent: ${sent}/${staffList.length}`, sent, total: staffList.length });

  } catch (err) {
    console.error("[STAFF-REPORT] Error:", (err as Error).message);
    return json({ error: (err as Error).message }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
