# Anti-Spam / Unsolicited-Message Footer Spec

Applies to every outbound message sent by `outreach-bulk-send` and `outreach-contact` (single-send), regardless of channel or template. Auto-appended by the edge function. Cannot be disabled or edited by senders.

## Why this exists

We are sending **unsolicited commercial communications** to salons that have not opted in. The salons' contact details come from public sources (Google Maps, DENUE, manual scrape). To send these messages legally we must satisfy three regimes:

1. **Mexico — LFPDPPP** (Ley Federal de Protección de Datos Personales en Posesión de los Particulares, reformada 2025-03-20, enforced by SABG)
   - Identifiable sender
   - Stated basis for the contact
   - Opt-out mechanism
   - Link to aviso de privacidad
2. **Mexico — REPEP / PROFECO**: B2B messaging falls outside REPEP scope, but identity + opt-out remain required best practice.
3. **US — CAN-SPAM** (15 U.S.C. §7704), in case any owner contact is a US-resident or US-domiciled email address:
   - Physical postal address
   - Clear, conspicuous unsubscribe link
   - Honor opt-out within 10 business days
   - No deceptive headers or subject lines
   - Identify the message as commercial (the contextual basis line covers this)

## Footer — WhatsApp

Appended after a single blank line below the template body.

```
—
BeautyCita S.A. de C.V. · Plaza Caracol L27, Puerto Vallarta, Jal., MX
Te contactamos porque {salon_name} aparece como negocio público.
Para no recibir más mensajes, responde: BAJA
```

Notes:
- One blank line above the em-dash separator.
- `{salon_name}` resolves per recipient.
- Plain text only. No emoji. No links — keeping the body's single link unique to the CTA.
- "BAJA" is a single uppercase keyword the inbound `wa-incoming` handler matches case-insensitively. Variants accepted: "baja", "stop", "unsubscribe".

## Footer — Email (HTML body)

Appended below the email signature with `<hr>` separator. Plain-text alternative also generated.

```html
<hr style="border: 0; border-top: 1px solid #ddd; margin: 24px 0 16px;">
<div style="font-size: 12px; color: #777; line-height: 1.5; font-family: sans-serif;">
  <p style="margin: 0 0 8px;">
    Recibes este mensaje porque <strong>{salon_name}</strong> aparece como negocio público en nuestro directorio.<br>
    You are receiving this because <strong>{salon_name}</strong> is listed as a public business in our directory.
  </p>
  <p style="margin: 0 0 8px;">
    <strong>BeautyCita S.A. de C.V.</strong><br>
    Plaza Caracol Local 27, Puerto Vallarta, Jalisco, México · CP 48330<br>
    <a href="mailto:hello@beautycita.com" style="color: #777;">hello@beautycita.com</a>
  </p>
  <p style="margin: 0;">
    <a href="{unsubscribe_link}" style="color: #777;">Darme de baja / Unsubscribe</a>
    &nbsp;·&nbsp;
    <a href="https://beautycita.com/privacidad" style="color: #777;">Aviso de privacidad / Privacy notice</a>
  </p>
</div>
```

## Unsubscribe link

`{unsubscribe_link}` resolves to:

```
https://beautycita.com/baja?t={token}
```

Where `{token}` is a per-recipient HMAC of `(channel + recipient_phone_or_email + salt)`. The `/baja` page:
1. Validates the token.
2. Inserts into `marketing_opt_outs` keyed on the underlying phone or email.
3. Shows confirmation in ES + EN.

Inbound BAJA on WhatsApp:
- `wa-incoming` edge fn matches the keyword on the message body.
- Inserts the sender's phone into `marketing_opt_outs`.
- Sends a confirmation reply: `Listo. No te volveremos a contactar.`

## Hard rules — never break

- Never send if the recipient phone or email exists in `marketing_opt_outs`.
- Never send if the discovered_salon row has `marketing_opt_out_at IS NOT NULL` (denormalized cache).
- Never send if a 14-day invite cooldown is active for that recipient.
- Never strip or alter this footer in code paths that touch `outreach-bulk-send` or `outreach-contact`.
- Honor opt-out across **all channels for that contact**: an email opt-out also blocks WA at that salon if the discovered_salon row links them, and vice-versa via the `marketing_opt_outs` row containing both fields where known.

## Audit retention

Every send is logged in `salon_outreach_log` with `bulk_job_id` (if applicable), `recipient_phone`, `recipient_email`, `template_id`, `message_text`, `subject`, `sent_at`, `delivered`, `error_text`. Retention: 5 years (matches CFF Art. 30 and CAN-SPAM evidentiary needs).
