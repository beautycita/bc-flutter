#!/usr/bin/env bash
# 03-replicate.sh — bootstrap the new MX instance with the IONOS stack.
#   1. Install Docker, nginx, basic deps
#   2. Pull latest DB dump from IONOS backups + restore
#   3. Rsync /var/www/beautycita.com tree (functions, configs, scripts)
#   4. Bring docker compose up (supabase + ghost + monitoring)
#
# Idempotent. Safe to re-run.
set -euo pipefail

source ~/.config/vultr/credentials
source ~/.config/vultr/instance.env  # provides VULTR_INSTANCE_IP

NEW_HOST="root@${VULTR_INSTANCE_IP}"

echo "═══ Step 1: System bootstrap on ${VULTR_INSTANCE_IP} ═══"
ssh -o StrictHostKeyChecking=accept-new "${NEW_HOST}" 'bash -s' <<'BOOTSTRAP'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates gnupg rsync nginx ufw fail2ban
# Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker
# www-data shell
usermod -s /bin/bash www-data || true
mkdir -p /var/www && chown www-data:www-data /var/www
# UFW: allow SSH + 80 + 443
ufw allow 22/tcp; ufw allow 80/tcp; ufw allow 443/tcp; ufw --force enable
echo "Bootstrap complete on $(hostname)"
BOOTSTRAP

echo
echo "═══ Step 2: Backup current prod DB (from IONOS) ═══"
ssh www-bc 'docker exec supabase-db pg_dump -U postgres -Fc -d postgres -f /tmp/migration-dump.pgc'
ssh www-bc 'docker cp supabase-db:/tmp/migration-dump.pgc /tmp/migration-dump.pgc'
ssh www-bc 'ls -lh /tmp/migration-dump.pgc'

echo
echo "═══ Step 3: Stream DB dump → new host ═══"
ssh www-bc 'cat /tmp/migration-dump.pgc' | ssh "${NEW_HOST}" 'cat > /tmp/migration-dump.pgc && ls -lh /tmp/migration-dump.pgc'

echo
echo "═══ Step 4: Rsync /var/www/beautycita.com (excluding heavy/runtime dirs) ═══"
# Stream IONOS → here → new host. Two hops because direct ssh-to-ssh needs ProxyJump.
ssh www-bc 'tar czf - --exclude="*.log" --exclude="node_modules" --exclude="*.apk" --exclude="*.ipa" --exclude="bc-flutter/supabase-docker/volumes/db" -C /var/www beautycita.com' \
  | ssh "${NEW_HOST}" 'mkdir -p /var/www && tar xzf - -C /var/www'

echo
echo "═══ Step 5: Bring up Supabase stack on new host ═══"
ssh "${NEW_HOST}" 'cd /var/www/beautycita.com/bc-flutter/supabase-docker && docker compose up -d'

echo
echo "═══ Step 6: Restore DB into new container ═══"
sleep 20  # let supabase-db come healthy
ssh "${NEW_HOST}" 'docker cp /tmp/migration-dump.pgc supabase-db:/tmp/migration-dump.pgc'
ssh "${NEW_HOST}" 'docker exec supabase-db pg_restore -U postgres -d postgres --clean --if-exists /tmp/migration-dump.pgc 2>&1 | tail -20'

echo
echo "═══ Done ═══"
echo "New stack live at http://${VULTR_INSTANCE_IP}"
echo "Test: curl -k https://${VULTR_INSTANCE_IP}/healthz"
echo "Next: ./04-cutover.sh  (DNS swap — coordinate timing)"
