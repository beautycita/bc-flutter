// =============================================================================
// notification_templates.ts — Read notification templates from DB (#31)
// =============================================================================
// Reads from the `notification_templates` table and applies variable
// substitution. Falls back to hardcoded text if no template found.
// =============================================================================

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

interface NotificationTemplate {
  id: string;
  event_type: string;
  channel: string;
  recipient_type: string;
  template_es: string;
  template_en: string;
  required_variables: string[];
  is_active: boolean;
}

/**
 * Fetch a notification template from the DB.
 * Returns null if not found or inactive.
 */
export async function getNotificationTemplate(
  supabase: SupabaseClient,
  eventType: string,
  channel: string,
  recipientType: string = "customer"
): Promise<NotificationTemplate | null> {
  try {
    const { data, error } = await supabase
      .from("notification_templates")
      .select("*")
      .eq("event_type", eventType)
      .eq("channel", channel)
      .eq("recipient_type", recipientType)
      .eq("is_active", true)
      .single();

    if (error || !data) {
      return null;
    }

    return data as NotificationTemplate;
  } catch {
    return null;
  }
}

/**
 * Apply variable substitution to a template string.
 * Variables in the template are written as {{VARIABLE_NAME}}.
 *
 * Example: "Hola {{USER_NAME}}, tu cita es el {{DATE}}"
 */
export function applyTemplate(
  template: string,
  variables: Record<string, string>
): string {
  let result = template;
  for (const [key, value] of Object.entries(variables)) {
    result = result.replace(new RegExp(`\\{\\{${key}\\}\\}`, "g"), value);
  }
  return result;
}

/**
 * Get a notification message: tries DB template first, falls back to provided default.
 *
 * @param supabase - Supabase client
 * @param eventType - e.g., "booking_confirmed", "review_request"
 * @param channel - e.g., "whatsapp", "push", "email"
 * @param recipientType - "customer" or "salon"
 * @param variables - key-value pairs for template substitution
 * @param fallbackText - hardcoded fallback if no template in DB
 * @returns The resolved message text
 */
export async function resolveNotificationText(
  supabase: SupabaseClient,
  eventType: string,
  channel: string,
  recipientType: string,
  variables: Record<string, string>,
  fallbackText: string
): Promise<string> {
  const template = await getNotificationTemplate(
    supabase,
    eventType,
    channel,
    recipientType
  );

  if (template) {
    return applyTemplate(template.template_es, variables);
  }

  return fallbackText;
}
