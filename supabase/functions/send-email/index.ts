// =============================================================================
// send-email — Send branded HTML emails via IONOS SMTP
// =============================================================================
// Templates: welcome, verification, booking-receipt, promotion
// Auth: service-role key only (no user auth)
// =============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import nodemailer from "npm:nodemailer@6.9.16";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SMTP_HOST = Deno.env.get("SMTP_HOST") ?? "smtp.ionos.mx";
const SMTP_PORT = parseInt(Deno.env.get("SMTP_PORT") ?? "587");
const SMTP_USER = Deno.env.get("SMTP_USER") ?? "";
const SMTP_PASS = Deno.env.get("SMTP_PASS") ?? "";
const SMTP_FROM = Deno.env.get("SMTP_FROM") ?? "no-reply@beautycita.com";
const SMTP_FROM_NAME = Deno.env.get("SMTP_FROM_NAME") ?? "BeautyCita";

// ---------------------------------------------------------------------------
// Templates
// ---------------------------------------------------------------------------

const TEMPLATES: Record<string, string> = {
  welcome: `<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="color-scheme" content="light">
  <meta name="supported-color-schemes" content="light">
  <title>Bienvenida a BeautyCita</title>
  <!--[if mso]>
  <noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
  <style>table{border-collapse:collapse;}td{font-family:Georgia,'Times New Roman',serif;}</style>
  <![endif]-->
  <style>
    body,table,td,p,a,li{-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}
    table,td{mso-table-lspace:0pt;mso-table-rspace:0pt;}
    img{-ms-interpolation-mode:bicubic;border:0;outline:none;text-decoration:none;}
    body{margin:0;padding:0;width:100%!important;height:100%!important;}
    .heading-gold{color:#D4AF37;font-family:Georgia,'Times New Roman',serif;font-weight:700;text-shadow:0 1px 2px rgba(139,105,20,0.25);letter-spacing:0.5px;}
    .cta-btn{display:inline-block;padding:14px 36px;background-color:#C2185B;color:#ffffff!important;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;text-decoration:none;border-radius:24px;letter-spacing:0.5px;}
    @media only screen and (max-width:620px){
      .email-container{width:100%!important;max-width:100%!important;}
      .content-padding{padding:24px 20px!important;}
      .corner-cell{width:30px!important;height:30px!important;}
      .corner-img{width:30px!important;height:30px!important;}
      .gold-border-padding{padding:6px!important;}
      .heading-gold{font-size:22px!important;}
    }
  </style>
</head>
<body style="margin:0;padding:0;background-color:#F5F0E8;font-family:Georgia,'Times New Roman',serif;">
  <div style="display:none;font-size:1px;color:#F5F0E8;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;">
    Tu cuenta BeautyCita esta lista. Descubre lo que puedes hacer.
  </div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#F5F0E8;">
    <tr>
      <td align="center" style="padding:24px 10px;">

        <!-- Gold outer border -->
        <table role="presentation" class="email-container" width="600" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;background-color:#D4AF37;background-image:linear-gradient(135deg,#8B6914 0%,#D4AF37 12%,#FFF8DC 28%,#FFD700 42%,#C19A26 58%,#F5D547 72%,#D4AF37 85%,#8B6914 100%);border-radius:4px;">
          <tr>
            <td class="gold-border-padding" style="padding:10px;">

              <!-- Maroon frame with corners -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;background-color:#7B1038;border-radius:2px;">
                <tr>
                  <td class="corner-cell" width="50" height="50" valign="top" align="left" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-tl.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                  <td style="background-color:#7B1038;border-bottom:2px solid #D4AF37;font-size:1px;line-height:1px;" height="50">&nbsp;</td>
                  <td class="corner-cell" width="50" height="50" valign="top" align="right" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-tr.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                </tr>
                <tr>
                  <td style="background-color:#7B1038;border-right:2px solid #D4AF37;font-size:1px;" width="50">&nbsp;</td>
                  <td style="background-color:#FFF8F0;" valign="top">

                    <!-- Content -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">

                      <!-- Logo -->
                      <tr>
                        <td class="content-padding" align="center" style="padding:36px 40px 20px 40px;">
                          <img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/brand/logo.png" width="70" height="70" alt="BeautyCita" style="display:block;border-radius:50%;">
                        </td>
                      </tr>

                      <!-- Divider -->
                      <tr>
                        <td align="center" style="padding:0 40px;">
                          <img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/gold-divider.png" width="400" height="10" alt="" style="display:block;max-width:100%;">
                        </td>
                      </tr>

                      <!-- Heading -->
                      <tr>
                        <td class="content-padding" align="center" style="padding:24px 40px 8px 40px;">
                          <h1 class="heading-gold" style="margin:0;font-size:28px;color:#D4AF37;font-family:Georgia,'Times New Roman',serif;font-weight:700;text-shadow:0 1px 2px rgba(139,105,20,0.25);">
                            Bienvenida
                          </h1>
                        </td>
                      </tr>

                      <!-- Body -->
                      <tr>
                        <td class="content-padding" style="padding:16px 40px 24px 40px;">
                          <p style="margin:0 0 16px 0;color:#212121;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;line-height:1.6;text-align:center;">
                            Hola <strong style="color:#C2185B;">{{USER_NAME}}</strong>,
                          </p>
                          <p style="margin:0 0 16px 0;color:#212121;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;line-height:1.6;text-align:center;">
                            Tu cuenta esta lista. Ahora puedes reservar servicios de belleza en segundos, sin llamadas ni esperas.
                          </p>
                          <p style="margin:0 0 8px 0;color:#757575;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:15px;line-height:1.6;text-align:center;">
                            Selecciona lo que necesitas y nosotros hacemos el resto.
                          </p>
                        </td>
                      </tr>

                      <!-- CTA -->
                      <tr>
                        <td align="center" style="padding:8px 40px 32px 40px;">
                          <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                            <tr>
                              <td align="center" style="border-radius:24px;background-color:#C2185B;">
                                <a href="https://beautycita.com/reservar" class="cta-btn" style="display:inline-block;padding:14px 36px;background-color:#C2185B;color:#ffffff;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;text-decoration:none;border-radius:24px;" target="_blank">
                                  RESERVAR AHORA
                                </a>
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>

                      <!-- Divider -->
                      <tr>
                        <td align="center" style="padding:0 40px;">
                          <img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/gold-divider.png" width="400" height="10" alt="" style="display:block;max-width:100%;">
                        </td>
                      </tr>

                      <!-- Footer -->
                      <tr>
                        <td class="content-padding" align="center" style="padding:20px 40px 32px 40px;">
                          <p style="margin:0 0 8px 0;color:#757575;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.5;">
                            Descarga la app para una experiencia completa.
                          </p>
                          <p style="margin:0;color:#9E9E9E;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:12px;line-height:1.5;">
                            &copy; 2026 BeautyCita &middot; Todos los derechos reservados
                          </p>
                        </td>
                      </tr>
                    </table>

                  </td>
                  <td style="background-color:#7B1038;border-left:2px solid #D4AF37;font-size:1px;" width="50">&nbsp;</td>
                </tr>
                <tr>
                  <td class="corner-cell" width="50" height="50" valign="bottom" align="left" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-bl.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                  <td style="background-color:#7B1038;border-top:2px solid #D4AF37;font-size:1px;line-height:1px;" height="50">&nbsp;</td>
                  <td class="corner-cell" width="50" height="50" valign="bottom" align="right" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-br.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                </tr>
              </table>

            </td>
          </tr>
        </table>

        <table role="presentation" class="email-container" width="600" cellpadding="0" cellspacing="0" border="0">
          <tr><td align="center" style="padding:16px 20px 0 20px;"><p style="margin:0;color:#9E9E9E;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:11px;">BeautyCita &middot; Guadalajara, Jalisco, Mexico</p></td></tr>
        </table>

      </td>
    </tr>
  </table>
</body>
</html>`,

  verification: `<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="color-scheme" content="light">
  <meta name="supported-color-schemes" content="light">
  <title>Codigo de Verificacion - BeautyCita</title>
  <!--[if mso]>
  <noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
  <style>table{border-collapse:collapse;}td{font-family:Georgia,'Times New Roman',serif;}</style>
  <![endif]-->
  <style>
    body,table,td,p,a,li{-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}
    table,td{mso-table-lspace:0pt;mso-table-rspace:0pt;}
    img{-ms-interpolation-mode:bicubic;border:0;outline:none;text-decoration:none;}
    body{margin:0;padding:0;width:100%!important;height:100%!important;}
    .heading-gold{color:#D4AF37;font-family:Georgia,'Times New Roman',serif;font-weight:700;text-shadow:0 1px 2px rgba(139,105,20,0.25);}
    @media only screen and (max-width:620px){
      .email-container{width:100%!important;max-width:100%!important;}
      .content-padding{padding:24px 20px!important;}
      .corner-cell{width:30px!important;height:30px!important;}
      .corner-img{width:30px!important;height:30px!important;}
      .gold-border-padding{padding:6px!important;}
      .heading-gold{font-size:22px!important;}
      .code-box{font-size:28px!important;letter-spacing:6px!important;padding:16px 20px!important;}
    }
  </style>
</head>
<body style="margin:0;padding:0;background-color:#F5F0E8;font-family:Georgia,'Times New Roman',serif;">
  <div style="display:none;font-size:1px;color:#F5F0E8;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;">
    Tu codigo de verificacion BeautyCita: {{CODE}}
  </div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#F5F0E8;">
    <tr>
      <td align="center" style="padding:24px 10px;">

        <!-- Gold outer border -->
        <table role="presentation" class="email-container" width="600" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;background-color:#D4AF37;background-image:linear-gradient(135deg,#8B6914 0%,#D4AF37 12%,#FFF8DC 28%,#FFD700 42%,#C19A26 58%,#F5D547 72%,#D4AF37 85%,#8B6914 100%);border-radius:4px;">
          <tr>
            <td class="gold-border-padding" style="padding:10px;">

              <!-- Maroon frame -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;background-color:#7B1038;border-radius:2px;">
                <tr>
                  <td class="corner-cell" width="50" height="50" valign="top" align="left" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-tl.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                  <td style="background-color:#7B1038;border-bottom:2px solid #D4AF37;font-size:1px;line-height:1px;" height="50">&nbsp;</td>
                  <td class="corner-cell" width="50" height="50" valign="top" align="right" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-tr.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                </tr>
                <tr>
                  <td style="background-color:#7B1038;border-right:2px solid #D4AF37;font-size:1px;" width="50">&nbsp;</td>
                  <td style="background-color:#FFF8F0;" valign="top">

                    <!-- Content -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">

                      <!-- Logo -->
                      <tr>
                        <td align="center" style="padding:36px 40px 20px 40px;">
                          <img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/brand/logo.png" width="70" height="70" alt="BeautyCita" style="display:block;border-radius:50%;">
                        </td>
                      </tr>

                      <!-- Divider -->
                      <tr>
                        <td align="center" style="padding:0 40px;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/gold-divider.png" width="400" height="10" alt="" style="display:block;max-width:100%;"></td>
                      </tr>

                      <!-- Heading -->
                      <tr>
                        <td class="content-padding" align="center" style="padding:24px 40px 8px 40px;">
                          <h1 class="heading-gold" style="margin:0;font-size:26px;color:#D4AF37;font-family:Georgia,'Times New Roman',serif;font-weight:700;text-shadow:0 1px 2px rgba(139,105,20,0.25);">
                            Codigo de Verificacion
                          </h1>
                        </td>
                      </tr>

                      <!-- Body text -->
                      <tr>
                        <td class="content-padding" align="center" style="padding:16px 40px 24px 40px;">
                          <p style="margin:0;color:#212121;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;line-height:1.6;">
                            Ingresa este codigo para verificar tu cuenta:
                          </p>
                        </td>
                      </tr>

                      <!-- Verification code box -->
                      <tr>
                        <td align="center" style="padding:0 40px 24px 40px;">
                          <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                            <tr>
                              <td class="code-box" align="center" style="padding:20px 40px;background-color:#7B1038;border:2px solid #D4AF37;border-radius:12px;color:#D4AF37;font-family:Georgia,'Times New Roman',serif;font-size:36px;font-weight:700;letter-spacing:10px;text-shadow:0 1px 2px rgba(139,105,20,0.3);">
                                {{CODE}}
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>

                      <!-- Expiry note -->
                      <tr>
                        <td align="center" style="padding:0 40px 32px 40px;">
                          <p style="margin:0;color:#757575;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:14px;line-height:1.5;">
                            Este codigo expira en <strong>10 minutos</strong>.
                          </p>
                          <p style="margin:8px 0 0 0;color:#9E9E9E;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.5;">
                            Si no solicitaste este codigo, puedes ignorar este correo.
                          </p>
                        </td>
                      </tr>

                      <!-- Divider -->
                      <tr>
                        <td align="center" style="padding:0 40px;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/gold-divider.png" width="400" height="10" alt="" style="display:block;max-width:100%;"></td>
                      </tr>

                      <!-- Footer -->
                      <tr>
                        <td align="center" style="padding:20px 40px 32px 40px;">
                          <p style="margin:0;color:#9E9E9E;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:12px;">
                            &copy; 2026 BeautyCita &middot; Todos los derechos reservados
                          </p>
                        </td>
                      </tr>
                    </table>

                  </td>
                  <td style="background-color:#7B1038;border-left:2px solid #D4AF37;font-size:1px;" width="50">&nbsp;</td>
                </tr>
                <tr>
                  <td class="corner-cell" width="50" height="50" valign="bottom" align="left" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-bl.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                  <td style="background-color:#7B1038;border-top:2px solid #D4AF37;font-size:1px;line-height:1px;" height="50">&nbsp;</td>
                  <td class="corner-cell" width="50" height="50" valign="bottom" align="right" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-br.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                </tr>
              </table>

            </td>
          </tr>
        </table>

        <table role="presentation" class="email-container" width="600" cellpadding="0" cellspacing="0" border="0">
          <tr><td align="center" style="padding:16px 20px 0 20px;"><p style="margin:0;color:#9E9E9E;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:11px;">BeautyCita &middot; Guadalajara, Jalisco, Mexico</p></td></tr>
        </table>

      </td>
    </tr>
  </table>
</body>
</html>`,

  "booking-receipt": `<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="color-scheme" content="light">
  <meta name="supported-color-schemes" content="light">
  <title>Recibo de Reserva - BeautyCita</title>
  <!--[if mso]>
  <noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
  <style>table{border-collapse:collapse;}td{font-family:Georgia,'Times New Roman',serif;}</style>
  <![endif]-->
  <style>
    body,table,td,p,a,li{-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}
    table,td{mso-table-lspace:0pt;mso-table-rspace:0pt;}
    img{-ms-interpolation-mode:bicubic;border:0;outline:none;text-decoration:none;}
    body{margin:0;padding:0;width:100%!important;height:100%!important;}
    .heading-gold{color:#D4AF37;font-family:Georgia,'Times New Roman',serif;font-weight:700;text-shadow:0 1px 2px rgba(139,105,20,0.25);letter-spacing:0.5px;}
    .cta-btn{display:inline-block;padding:14px 36px;background-color:#C2185B;color:#ffffff!important;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;text-decoration:none;border-radius:24px;}
    @media only screen and (max-width:620px){
      .email-container{width:100%!important;max-width:100%!important;}
      .content-padding{padding:24px 20px!important;}
      .corner-cell{width:30px!important;height:30px!important;}
      .corner-img{width:30px!important;height:30px!important;}
      .gold-border-padding{padding:6px!important;}
      .heading-gold{font-size:22px!important;}
      .receipt-table td{padding:8px 12px!important;font-size:14px!important;}
    }
  </style>
</head>
<body style="margin:0;padding:0;background-color:#F5F0E8;font-family:Georgia,'Times New Roman',serif;">
  <div style="display:none;font-size:1px;color:#F5F0E8;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;">
    Tu recibo de reserva #{{BOOKING_ID}} en {{SALON_NAME}}
  </div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#F5F0E8;">
    <tr>
      <td align="center" style="padding:24px 10px;">

        <!-- Gold outer border -->
        <table role="presentation" class="email-container" width="600" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;background-color:#D4AF37;background-image:linear-gradient(135deg,#8B6914 0%,#D4AF37 12%,#FFF8DC 28%,#FFD700 42%,#C19A26 58%,#F5D547 72%,#D4AF37 85%,#8B6914 100%);border-radius:4px;">
          <tr>
            <td class="gold-border-padding" style="padding:10px;">

              <!-- Maroon frame -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;background-color:#7B1038;border-radius:2px;">
                <tr>
                  <td class="corner-cell" width="50" height="50" valign="top" align="left" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-tl.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                  <td style="background-color:#7B1038;border-bottom:2px solid #D4AF37;font-size:1px;line-height:1px;" height="50">&nbsp;</td>
                  <td class="corner-cell" width="50" height="50" valign="top" align="right" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-tr.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                </tr>
                <tr>
                  <td style="background-color:#7B1038;border-right:2px solid #D4AF37;font-size:1px;" width="50">&nbsp;</td>
                  <td style="background-color:#FFF8F0;" valign="top">

                    <!-- Content -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">

                      <!-- Logo -->
                      <tr>
                        <td align="center" style="padding:36px 40px 20px 40px;">
                          <img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/brand/logo.png" width="70" height="70" alt="BeautyCita" style="display:block;border-radius:50%;">
                        </td>
                      </tr>

                      <!-- Divider -->
                      <tr>
                        <td align="center" style="padding:0 40px;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/gold-divider.png" width="400" height="10" alt="" style="display:block;max-width:100%;"></td>
                      </tr>

                      <!-- Heading -->
                      <tr>
                        <td class="content-padding" align="center" style="padding:24px 40px 4px 40px;">
                          <h1 class="heading-gold" style="margin:0;font-size:26px;color:#D4AF37;font-family:Georgia,'Times New Roman',serif;font-weight:700;text-shadow:0 1px 2px rgba(139,105,20,0.25);">
                            Recibo de Reserva
                          </h1>
                        </td>
                      </tr>

                      <!-- Booking ID -->
                      <tr>
                        <td align="center" style="padding:4px 40px 16px 40px;">
                          <p style="margin:0;color:#757575;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:14px;">
                            Reserva #{{BOOKING_ID}}
                          </p>
                        </td>
                      </tr>

                      <!-- Receipt details table -->
                      <tr>
                        <td class="content-padding" style="padding:0 40px 24px 40px;">
                          <table role="presentation" class="receipt-table" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;">

                            <!-- Salon -->
                            <tr>
                              <td style="padding:12px 16px;border-bottom:1px solid #EEEEEE;color:#757575;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:14px;" width="40%">
                                Salon
                              </td>
                              <td style="padding:12px 16px;border-bottom:1px solid #EEEEEE;color:#212121;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:15px;font-weight:600;">
                                {{SALON_NAME}}
                              </td>
                            </tr>

                            <!-- Service -->
                            <tr>
                              <td style="padding:12px 16px;border-bottom:1px solid #EEEEEE;color:#757575;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:14px;">
                                Servicio
                              </td>
                              <td style="padding:12px 16px;border-bottom:1px solid #EEEEEE;color:#212121;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:15px;font-weight:600;">
                                {{SERVICE_NAME}}
                              </td>
                            </tr>

                            <!-- Stylist -->
                            <tr>
                              <td style="padding:12px 16px;border-bottom:1px solid #EEEEEE;color:#757575;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:14px;">
                                Estilista
                              </td>
                              <td style="padding:12px 16px;border-bottom:1px solid #EEEEEE;color:#212121;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:15px;">
                                {{STYLIST_NAME}}
                              </td>
                            </tr>

                            <!-- Date -->
                            <tr>
                              <td style="padding:12px 16px;border-bottom:1px solid #EEEEEE;color:#757575;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:14px;">
                                Fecha
                              </td>
                              <td style="padding:12px 16px;border-bottom:1px solid #EEEEEE;color:#212121;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:15px;font-weight:600;">
                                {{BOOKING_DATE}}
                              </td>
                            </tr>

                            <!-- Time -->
                            <tr>
                              <td style="padding:12px 16px;border-bottom:1px solid #EEEEEE;color:#757575;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:14px;">
                                Hora
                              </td>
                              <td style="padding:12px 16px;border-bottom:1px solid #EEEEEE;color:#212121;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:15px;font-weight:600;">
                                {{BOOKING_TIME}}
                              </td>
                            </tr>

                            <!-- Duration -->
                            <tr>
                              <td style="padding:12px 16px;border-bottom:1px solid #EEEEEE;color:#757575;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:14px;">
                                Duracion
                              </td>
                              <td style="padding:12px 16px;border-bottom:1px solid #EEEEEE;color:#212121;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:15px;">
                                {{DURATION}}
                              </td>
                            </tr>

                            <!-- Total (gold highlight) -->
                            <tr>
                              <td style="padding:14px 16px;color:#D4AF37;font-family:Georgia,'Times New Roman',serif;font-size:16px;font-weight:700;">
                                Total
                              </td>
                              <td style="padding:14px 16px;color:#D4AF37;font-family:Georgia,'Times New Roman',serif;font-size:20px;font-weight:700;text-shadow:0 1px 1px rgba(139,105,20,0.15);">
                                {{TOTAL_AMOUNT}}
                              </td>
                            </tr>

                          </table>
                        </td>
                      </tr>

                      <!-- Payment method -->
                      <tr>
                        <td class="content-padding" align="center" style="padding:0 40px 24px 40px;">
                          <p style="margin:0;color:#757575;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.5;">
                            Pagado con {{PAYMENT_METHOD}}
                          </p>
                        </td>
                      </tr>

                      <!-- CTA -->
                      <tr>
                        <td align="center" style="padding:0 40px 32px 40px;">
                          <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                            <tr>
                              <td align="center" style="border-radius:24px;background-color:#C2185B;">
                                <a href="https://beautycita.com/mis-citas" class="cta-btn" style="display:inline-block;padding:14px 36px;background-color:#C2185B;color:#ffffff;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;text-decoration:none;border-radius:24px;" target="_blank">
                                  VER MIS CITAS
                                </a>
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>

                      <!-- Divider -->
                      <tr>
                        <td align="center" style="padding:0 40px;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/gold-divider.png" width="400" height="10" alt="" style="display:block;max-width:100%;"></td>
                      </tr>

                      <!-- Footer -->
                      <tr>
                        <td align="center" style="padding:20px 40px 32px 40px;">
                          <p style="margin:0 0 4px 0;color:#757575;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.5;">
                            Necesitas cambiar o cancelar? Hazlo desde la app.
                          </p>
                          <p style="margin:0;color:#9E9E9E;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:12px;">
                            &copy; 2026 BeautyCita &middot; Todos los derechos reservados
                          </p>
                        </td>
                      </tr>
                    </table>

                  </td>
                  <td style="background-color:#7B1038;border-left:2px solid #D4AF37;font-size:1px;" width="50">&nbsp;</td>
                </tr>
                <tr>
                  <td class="corner-cell" width="50" height="50" valign="bottom" align="left" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-bl.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                  <td style="background-color:#7B1038;border-top:2px solid #D4AF37;font-size:1px;line-height:1px;" height="50">&nbsp;</td>
                  <td class="corner-cell" width="50" height="50" valign="bottom" align="right" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-br.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                </tr>
              </table>

            </td>
          </tr>
        </table>

        <table role="presentation" class="email-container" width="600" cellpadding="0" cellspacing="0" border="0">
          <tr><td align="center" style="padding:16px 20px 0 20px;"><p style="margin:0;color:#9E9E9E;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:11px;">BeautyCita &middot; Guadalajara, Jalisco, Mexico</p></td></tr>
        </table>

      </td>
    </tr>
  </table>
</body>
</html>`,

  promotion: `<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office" lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="color-scheme" content="light">
  <meta name="supported-color-schemes" content="light">
  <title>{{PROMO_TITLE}} - BeautyCita</title>
  <!--[if mso]>
  <noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
  <style>table{border-collapse:collapse;}td{font-family:Georgia,'Times New Roman',serif;}</style>
  <![endif]-->
  <style>
    body,table,td,p,a,li{-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}
    table,td{mso-table-lspace:0pt;mso-table-rspace:0pt;}
    img{-ms-interpolation-mode:bicubic;border:0;outline:none;text-decoration:none;}
    body{margin:0;padding:0;width:100%!important;height:100%!important;}
    .heading-gold{color:#D4AF37;font-family:Georgia,'Times New Roman',serif;font-weight:700;text-shadow:0 1px 2px rgba(139,105,20,0.25);}
    .cta-btn-gold{display:inline-block;padding:14px 36px;background-color:#D4AF37;background-image:linear-gradient(135deg,#8B6914,#D4AF37 20%,#FFF8DC 45%,#FFD700 65%,#D4AF37 85%,#8B6914);color:#212121!important;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;text-decoration:none;border-radius:24px;letter-spacing:0.5px;}
    @media only screen and (max-width:620px){
      .email-container{width:100%!important;max-width:100%!important;}
      .content-padding{padding:24px 20px!important;}
      .corner-cell{width:30px!important;height:30px!important;}
      .corner-img{width:30px!important;height:30px!important;}
      .gold-border-padding{padding:6px!important;}
      .heading-gold{font-size:22px!important;}
      .promo-amount{font-size:40px!important;}
    }
  </style>
</head>
<body style="margin:0;padding:0;background-color:#F5F0E8;font-family:Georgia,'Times New Roman',serif;">
  <div style="display:none;font-size:1px;color:#F5F0E8;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;">
    {{PROMO_PREHEADER}}
  </div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#F5F0E8;">
    <tr>
      <td align="center" style="padding:24px 10px;">

        <!-- Gold outer border -->
        <table role="presentation" class="email-container" width="600" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;background-color:#D4AF37;background-image:linear-gradient(135deg,#8B6914 0%,#D4AF37 12%,#FFF8DC 28%,#FFD700 42%,#C19A26 58%,#F5D547 72%,#D4AF37 85%,#8B6914 100%);border-radius:4px;">
          <tr>
            <td class="gold-border-padding" style="padding:10px;">

              <!-- Maroon frame -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;background-color:#7B1038;border-radius:2px;">
                <tr>
                  <td class="corner-cell" width="50" height="50" valign="top" align="left" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-tl.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                  <td style="background-color:#7B1038;border-bottom:2px solid #D4AF37;font-size:1px;line-height:1px;" height="50">&nbsp;</td>
                  <td class="corner-cell" width="50" height="50" valign="top" align="right" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-tr.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                </tr>
                <tr>
                  <td style="background-color:#7B1038;border-right:2px solid #D4AF37;font-size:1px;" width="50">&nbsp;</td>
                  <td style="background-color:#FFF8F0;" valign="top">

                    <!-- Content -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">

                      <!-- Logo -->
                      <tr>
                        <td align="center" style="padding:36px 40px 20px 40px;">
                          <img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/brand/logo.png" width="70" height="70" alt="BeautyCita" style="display:block;border-radius:50%;">
                        </td>
                      </tr>

                      <!-- Divider -->
                      <tr>
                        <td align="center" style="padding:0 40px;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/gold-divider.png" width="400" height="10" alt="" style="display:block;max-width:100%;"></td>
                      </tr>

                      <!-- Promo heading -->
                      <tr>
                        <td class="content-padding" align="center" style="padding:24px 40px 8px 40px;">
                          <h1 class="heading-gold" style="margin:0;font-size:26px;color:#D4AF37;font-family:Georgia,'Times New Roman',serif;font-weight:700;text-shadow:0 1px 2px rgba(139,105,20,0.25);">
                            {{PROMO_TITLE}}
                          </h1>
                        </td>
                      </tr>

                      <!-- Big promo amount/percentage -->
                      <tr>
                        <td align="center" style="padding:16px 40px 8px 40px;">
                          <p class="promo-amount" style="margin:0;color:#C2185B;font-family:Georgia,'Times New Roman',serif;font-size:52px;font-weight:700;line-height:1;text-shadow:0 2px 4px rgba(194,24,91,0.2);">
                            {{PROMO_AMOUNT}}
                          </p>
                        </td>
                      </tr>

                      <!-- Promo subtitle -->
                      <tr>
                        <td align="center" style="padding:4px 40px 24px 40px;">
                          <p style="margin:0;color:#757575;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;line-height:1.5;">
                            {{PROMO_SUBTITLE}}
                          </p>
                        </td>
                      </tr>

                      <!-- Promo description -->
                      <tr>
                        <td class="content-padding" style="padding:0 40px 24px 40px;">
                          <p style="margin:0;color:#212121;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;line-height:1.6;text-align:center;">
                            {{PROMO_DESCRIPTION}}
                          </p>
                        </td>
                      </tr>

                      <!-- Promo code (if applicable) -->
                      <!-- {{PROMO_CODE_START}}
                      <tr>
                        <td align="center" style="padding:0 40px 24px 40px;">
                          <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                            <tr>
                              <td style="padding:12px 28px;border:2px dashed #D4AF37;border-radius:8px;background-color:#FFF8F0;">
                                <span style="color:#D4AF37;font-family:Georgia,'Times New Roman',serif;font-size:20px;font-weight:700;letter-spacing:3px;">{{PROMO_CODE}}</span>
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                      {{PROMO_CODE_END}} -->

                      <!-- Gold CTA button -->
                      <tr>
                        <td align="center" style="padding:8px 40px 16px 40px;">
                          <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                            <tr>
                              <td align="center" style="border-radius:24px;background-color:#D4AF37;background-image:linear-gradient(135deg,#8B6914,#D4AF37 20%,#FFF8DC 45%,#FFD700 65%,#D4AF37 85%,#8B6914);">
                                <a href="{{PROMO_CTA_URL}}" class="cta-btn-gold" style="display:inline-block;padding:14px 36px;color:#212121;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;font-weight:700;text-decoration:none;border-radius:24px;letter-spacing:0.5px;" target="_blank">
                                  {{PROMO_CTA_TEXT}}
                                </a>
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>

                      <!-- Expiry -->
                      <tr>
                        <td align="center" style="padding:4px 40px 32px 40px;">
                          <p style="margin:0;color:#9E9E9E;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:13px;">
                            Valido hasta {{PROMO_EXPIRY}}
                          </p>
                        </td>
                      </tr>

                      <!-- Divider -->
                      <tr>
                        <td align="center" style="padding:0 40px;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/gold-divider.png" width="400" height="10" alt="" style="display:block;max-width:100%;"></td>
                      </tr>

                      <!-- Footer -->
                      <tr>
                        <td align="center" style="padding:20px 40px 32px 40px;">
                          <p style="margin:0 0 8px 0;color:#9E9E9E;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:12px;">
                            &copy; 2026 BeautyCita &middot; Todos los derechos reservados
                          </p>
                          <p style="margin:0;font-size:12px;">
                            <a href="{{UNSUBSCRIBE_URL}}" style="color:#9E9E9E;text-decoration:underline;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:11px;">Cancelar suscripcion</a>
                          </p>
                        </td>
                      </tr>
                    </table>

                  </td>
                  <td style="background-color:#7B1038;border-left:2px solid #D4AF37;font-size:1px;" width="50">&nbsp;</td>
                </tr>
                <tr>
                  <td class="corner-cell" width="50" height="50" valign="bottom" align="left" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-bl.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                  <td style="background-color:#7B1038;border-top:2px solid #D4AF37;font-size:1px;line-height:1px;" height="50">&nbsp;</td>
                  <td class="corner-cell" width="50" height="50" valign="bottom" align="right" style="background-color:#7B1038;"><img src="https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/media/email/corner-br.png" class="corner-img" width="50" height="50" alt="" style="display:block;"></td>
                </tr>
              </table>

            </td>
          </tr>
        </table>

        <table role="presentation" class="email-container" width="600" cellpadding="0" cellspacing="0" border="0">
          <tr><td align="center" style="padding:16px 20px 0 20px;"><p style="margin:0;color:#9E9E9E;font-family:'Nunito','Segoe UI',Helvetica,Arial,sans-serif;font-size:11px;">BeautyCita &middot; Guadalajara, Jalisco, Mexico</p></td></tr>
        </table>

      </td>
    </tr>
  </table>
</body>
</html>`,
};

// ---------------------------------------------------------------------------
// Template variable replacement
// ---------------------------------------------------------------------------

function renderTemplate(
  templateName: string,
  variables: Record<string, string>,
): string {
  const html = TEMPLATES[templateName];
  if (!html) {
    throw new Error(`Unknown template: ${templateName}`);
  }

  let rendered = html;
  for (const [key, value] of Object.entries(variables)) {
    rendered = rendered.replaceAll(`{{${key}}}`, value);
  }

  // If PROMO_CODE is provided, uncomment the promo code block
  if (variables.PROMO_CODE) {
    rendered = rendered
      .replace("<!-- {{PROMO_CODE_START}}", "")
      .replace("{{PROMO_CODE_END}} -->", "");
  }

  return rendered;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

interface SendEmailRequest {
  template: string;
  to: string;
  subject: string;
  variables: Record<string, string>;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body: SendEmailRequest = await req.json();
    const { template, to, subject, variables } = body;

    if (!template || !to || !subject) {
      return json({ error: "template, to, and subject are required" }, 400);
    }

    if (!TEMPLATES[template]) {
      return json(
        {
          error: `Unknown template: ${template}. Valid: ${Object.keys(TEMPLATES).join(", ")}`,
        },
        400,
      );
    }

    const html = renderTemplate(template, variables ?? {});

    // Send via SMTP using nodemailer
    const transporter = nodemailer.createTransport({
      host: SMTP_HOST,
      port: SMTP_PORT,
      secure: false,
      auth: {
        user: SMTP_USER,
        pass: SMTP_PASS,
      },
    });

    await transporter.sendMail({
      from: `"${SMTP_FROM_NAME}" <${SMTP_FROM}>`,
      to,
      subject,
      html,
    });

    console.log(`[EMAIL] Sent "${template}" to ${to} — subject: ${subject}`);

    return json({ success: true, template, to });
  } catch (err) {
    console.error("[EMAIL] Error:", (err as Error).message);
    return json({ error: (err as Error).message }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
