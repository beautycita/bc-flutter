# Infrastructure Fixes: SMTP, Google OAuth, Stripe, Avatar Upload

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the three broken security screen features (Google link, email add, payment methods) and ensure avatar upload works reliably.

**Architecture:** All fixes are server-side configuration on the self-hosted Supabase instance at `beautycita.com`. SMTP needs real credentials wired into GoTrue. Google OAuth needs the provider enabled in GoTrue config. Stripe edge function needs `STRIPE_SECRET_KEY` set. Avatar storage bucket was already created but needs the `stripe_customer_id` column migration applied.

**Tech Stack:** Supabase self-hosted (Docker), GoTrue auth, Nginx, Deno edge functions, Stripe API, IONOS SMTP, Google OAuth

**Server Access:** `ssh www-bc` (user `www-data`, home `/var/www`)
**Supabase Docker:** `/var/www/beautycita.com/bc-flutter/supabase-docker/`
**Supabase DB:** `docker exec -i supabase-db psql -U supabase_admin -d postgres`

---

### Task 1: Configure Real SMTP in Supabase GoTrue

The email "add" feature fails because Supabase GoTrue is configured with fake SMTP (Inbucket). Real SMTP credentials exist: IONOS at `smtp.ionos.mx:587`, user `support@beautycita.com`, password `<SMTP_PASSWORD>`.

**Files:**
- Modify: Server file `/var/www/beautycita.com/bc-flutter/supabase-docker/.env`
- Modify: Server file `/var/www/beautycita.com/bc-flutter/supabase-docker/docker-compose.yml` (verify GoTrue env vars)

**Step 1: SSH in and read current SMTP config**

```bash
ssh www-bc "grep -E 'SMTP|MAILER|EMAIL' /var/www/beautycita.com/bc-flutter/supabase-docker/.env"
```

Expected: Shows fake SMTP values (`supabase-mail`, port 2500, `fake_mail_user`).

**Step 2: Update .env with real SMTP credentials**

Replace these values in the `.env`:

```
SMTP_ADMIN_EMAIL=support@beautycita.com
SMTP_HOST=smtp.ionos.mx
SMTP_PORT=587
SMTP_USER=support@beautycita.com
SMTP_PASS=<SMTP_PASSWORD>
SMTP_SENDER_NAME=BeautyCita
```

```bash
ssh www-bc "sed -i \
  -e 's|SMTP_ADMIN_EMAIL=.*|SMTP_ADMIN_EMAIL=support@beautycita.com|' \
  -e 's|SMTP_HOST=.*|SMTP_HOST=smtp.ionos.mx|' \
  -e 's|SMTP_PORT=.*|SMTP_PORT=587|' \
  -e 's|SMTP_USER=.*|SMTP_USER=support@beautycita.com|' \
  -e 's|SMTP_PASS=.*|SMTP_PASS=<SMTP_PASSWORD>|' \
  -e 's|SMTP_SENDER_NAME=.*|SMTP_SENDER_NAME=BeautyCita|' \
  /var/www/beautycita.com/bc-flutter/supabase-docker/.env"
```

**Step 3: Verify the GoTrue container picks up SMTP env vars**

Check docker-compose.yml to confirm GoTrue service references these env vars:

```bash
ssh www-bc "grep -A2 'SMTP\|GOTRUE_SMTP' /var/www/beautycita.com/bc-flutter/supabase-docker/docker-compose.yml | head -20"
```

GoTrue expects vars like `GOTRUE_SMTP_HOST`, `GOTRUE_SMTP_PORT`, etc. If the docker-compose maps `.env` vars to `GOTRUE_SMTP_*`, we're good. If not, add the mapping.

**Step 4: Restart GoTrue container**

```bash
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart supabase-auth"
```

**Step 5: Test email delivery**

From the app, go to Security > Agregar email > enter a real email. Should receive a confirmation email from `support@beautycita.com`.

**Step 6: Commit** (no local code changes needed)

---

### Task 2: Enable Google OAuth Provider in Supabase GoTrue

Google OAuth client ID and secret are already in the `.env` (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`). The issue is that GoTrue needs the Google provider explicitly enabled.

**Files:**
- Modify: Server `.env` (ensure `GOTRUE_EXTERNAL_GOOGLE_ENABLED=true`)
- Verify: Google Cloud Console redirect URI includes `https://beautycita.com/supabase/auth/v1/callback`

**Step 1: Check current Google provider config**

```bash
ssh www-bc "grep -i 'GOOGLE\|GOTRUE_EXTERNAL' /var/www/beautycita.com/bc-flutter/supabase-docker/.env"
```

**Step 2: Ensure Google provider is enabled in GoTrue**

Add/update these in `.env`:

```
GOTRUE_EXTERNAL_GOOGLE_ENABLED=true
GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID=<GOOGLE_CLIENT_ID>
GOTRUE_EXTERNAL_GOOGLE_SECRET=<GOOGLE_CLIENT_SECRET>
GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI=https://beautycita.com/supabase/auth/v1/callback
```

Check docker-compose to see if these need to be mapped to the auth container env.

**Step 3: Verify Google Cloud Console has correct redirect URI**

The redirect URI `https://beautycita.com/supabase/auth/v1/callback` must be listed in Google Cloud Console > APIs & Services > Credentials > OAuth 2.0 Client > Authorized redirect URIs.

Note: The app uses `linkIdentityWithIdToken` (native Google Sign-In SDK → ID token → Supabase), which does NOT use server-side OAuth redirect. It only needs the client ID to be correct in GoTrue config so it can verify the ID token. The redirect URI is needed for web OAuth flow only.

**Step 4: Restart GoTrue**

```bash
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart supabase-auth"
```

**Step 5: Test Google linking**

From app: Security > Vincular Google > Google sign-in sheet appears > authorize > should link successfully.

---

### Task 3: Set Stripe Secret Key on Edge Functions

The `stripe-payment-methods` edge function needs `STRIPE_SECRET_KEY` in its runtime environment. The test key is: `<STRIPE_SECRET_KEY>`

**Files:**
- Modify: Supabase edge function environment config on server

**Step 1: Check how edge function secrets are configured**

```bash
ssh www-bc "ls /var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/ 2>/dev/null"
ssh www-bc "grep -r 'STRIPE\|functions' /var/www/beautycita.com/bc-flutter/supabase-docker/docker-compose.yml | head -10"
```

Self-hosted Supabase edge functions get env vars from the `.env` or from `docker-compose.yml` environment section for the `supabase-edge-functions` or `supabase-functions` container.

**Step 2: Add STRIPE_SECRET_KEY to edge function env**

Add to `.env`:
```
STRIPE_SECRET_KEY=<STRIPE_SECRET_KEY>
```

Ensure the functions container passes this through. May need to add to docker-compose environment section.

**Step 3: Apply stripe_customer_id migration**

The `profiles` table needs the `stripe_customer_id` column:

```bash
ssh www-bc "docker exec -i supabase-db psql -U supabase_admin -d postgres -c \"ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS stripe_customer_id text;\""
```

**Step 4: Restart edge functions container**

```bash
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart supabase-edge-functions"
```

Or whatever the functions container is named. Check with:
```bash
ssh www-bc "docker ps --format '{{.Names}}' | grep -i func"
```

**Step 5: Test payment method addition**

From app: Security > Metodos de pago > Agregar tarjeta. Should show Stripe PaymentSheet. Use test card `4242 4242 4242 4242`, any future expiry, any CVC.

---

### Task 4: Verify Avatar Upload Works

The `avatars` storage bucket was created with RLS policies in the previous session. Verify it works.

**Step 1: Test "Subir foto" flow**

From app: Profile > tap avatar > Subir foto > pick image > crop > Confirmar.

Expected: Toast shows "Subiendo foto (XXX KB)..." then "Foto actualizada". Avatar updates.

**Step 2: If still failing, check RLS policy**

```bash
ssh www-bc "docker exec -i supabase-db psql -U supabase_admin -d postgres -c \"SELECT policyname, cmd FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage';\""
```

Should show the three policies created: upload, update, select.

**Step 3: If bucket or policies missing, recreate**

```bash
ssh www-bc "docker exec -i supabase-db psql -U supabase_admin -d postgres" <<'SQL'
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT (id) DO NOTHING;

CREATE POLICY IF NOT EXISTS "Users can upload own avatar"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY IF NOT EXISTS "Users can update own avatar"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY IF NOT EXISTS "Public read avatars"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'avatars');
SQL
```

**Step 4: Test "Crear avatar IA" flow**

From app: Profile > tap avatar > Crear avatar IA > pick image > crop > Confirmar.

Expected: Loading dialog "Creando tu avatar..." > LightX processes > downloads result > uploads to Supabase storage > avatar updates > saved to user_media.

---

### Task 5: Deploy Edge Functions

Ensure all edge functions are deployed with the latest code, especially `stripe-payment-methods`.

**Step 1: Check deployed functions**

```bash
ssh www-bc "docker exec supabase-edge-functions ls /home/deno/functions/ 2>/dev/null || echo 'check container name'"
```

**Step 2: Copy latest functions to server**

```bash
rsync -avz /home/bc/futureBeauty/beautycita_app/supabase/functions/ www-bc:/var/www/beautycita.com/bc-flutter/supabase-docker/volumes/functions/
```

Adjust the target path based on where the docker volume mounts functions from.

**Step 3: Restart functions container**

```bash
ssh www-bc "cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose restart supabase-edge-functions"
```

---

## Verification Checklist

1. [ ] Email: Security > Agregar email > receives real confirmation email
2. [ ] Google: Security > Vincular Google > Google sign-in completes > linked
3. [ ] Stripe: Security > Agregar tarjeta > Stripe PaymentSheet appears > test card works
4. [ ] Avatar upload: Profile > Subir foto > crop > upload succeeds
5. [ ] Avatar AI: Profile > Crear avatar IA > crop > LightX processes > avatar updates
6. [ ] Username edit: Profile > tap username > edit > save persists
