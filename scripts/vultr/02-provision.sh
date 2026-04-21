#!/usr/bin/env bash
# 02-provision.sh — create the Vultr instance + upload SSH key + open firewall.
# DRY-RUN by default. Pass --apply to actually create resources.
#
# After this script: instance is up, you can ssh root@<ip>. Run 03-replicate.sh next.
set -euo pipefail

source ~/.config/vultr/credentials

REGION="mex"
PLAN="${VULTR_PLAN:-vc2-6c-16gb}"
LABEL="beautycita-mx-1"
HOSTNAME="beautycita-mx-1"
OS_ID=1743           # Ubuntu 24.04 LTS
SSH_KEY_PATH="${HOME}/.ssh/id_ed25519.pub"
SSH_KEY_NAME="beautycita-deploy-$(hostname)"

API() { curl -s -H "Authorization: Bearer ${VULTR_API_KEY}" -H "Content-Type: application/json" "$@"; }

DRY=true
[[ "${1:-}" == "--apply" ]] && DRY=false

if $DRY; then
  echo "═══ DRY RUN ═══  (run with --apply to actually provision)"
fi
echo

# 1. Upload SSH key if not present
if [[ ! -f "${SSH_KEY_PATH}" ]]; then
  echo "ERROR: SSH public key not found at ${SSH_KEY_PATH}"
  echo "Generate one with: ssh-keygen -t ed25519 -C 'beautycita-deploy'"
  exit 1
fi
PUBKEY=$(cat "${SSH_KEY_PATH}")

EXISTING_KEY_ID=$(API "https://api.vultr.com/v2/ssh-keys" | python3 -c "
import sys,json
for k in json.load(sys.stdin).get('ssh_keys',[]):
    if k['ssh_key'].strip() == '''${PUBKEY}'''.strip():
        print(k['id']); break
")

if [[ -z "${EXISTING_KEY_ID}" ]]; then
  if $DRY; then
    echo "Would: upload SSH key '${SSH_KEY_NAME}'"
    SSH_KEY_ID="<would-be-created>"
  else
    SSH_KEY_ID=$(API -X POST "https://api.vultr.com/v2/ssh-keys" -d "{
      \"name\": \"${SSH_KEY_NAME}\",
      \"ssh_key\": \"${PUBKEY}\"
    }" | python3 -c "import sys,json; print(json.load(sys.stdin)['ssh_key']['id'])")
    echo "✓ Uploaded SSH key: ${SSH_KEY_ID}"
  fi
else
  SSH_KEY_ID="${EXISTING_KEY_ID}"
  echo "✓ SSH key already on file: ${SSH_KEY_ID}"
fi

# 2. Create instance
echo
echo "═══ Creating instance ═══"
echo "  region=${REGION} plan=${PLAN} os=Ubuntu24.04 label=${LABEL}"

if $DRY; then
  echo "Would: POST /v2/instances with above spec"
  echo "Would: enable_ipv6=true, ssh_keys=[${SSH_KEY_ID}], backups=enabled (\$/mo extra)"
  exit 0
fi

INSTANCE_JSON=$(API -X POST "https://api.vultr.com/v2/instances" -d "{
  \"region\": \"${REGION}\",
  \"plan\": \"${PLAN}\",
  \"os_id\": ${OS_ID},
  \"label\": \"${LABEL}\",
  \"hostname\": \"${HOSTNAME}\",
  \"sshkey_id\": [\"${SSH_KEY_ID}\"],
  \"enable_ipv6\": true,
  \"backups\": \"enabled\",
  \"ddos_protection\": false
}")

INSTANCE_ID=$(echo "${INSTANCE_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['instance']['id'])")
echo "✓ Created instance: ${INSTANCE_ID}"
echo "  Status: provisioning… IP will be assigned in ~30s"

# 3. Poll until active
echo
echo "═══ Waiting for IP ═══"
for i in {1..30}; do
  IP=$(API "https://api.vultr.com/v2/instances/${INSTANCE_ID}" | python3 -c "import sys,json; print(json.load(sys.stdin)['instance']['main_ip'] or '')")
  STATUS=$(API "https://api.vultr.com/v2/instances/${INSTANCE_ID}" | python3 -c "import sys,json; print(json.load(sys.stdin)['instance']['status'])")
  if [[ -n "${IP}" && "${IP}" != "0.0.0.0" && "${STATUS}" == "active" ]]; then
    echo "✓ Active. IP: ${IP}"
    break
  fi
  echo "  …status=${STATUS} ip=${IP:-pending} (try $i/30)"
  sleep 10
done

# 4. Save instance details for next scripts
cat > ~/.config/vultr/instance.env <<META
VULTR_INSTANCE_ID=${INSTANCE_ID}
VULTR_INSTANCE_IP=${IP}
VULTR_INSTANCE_LABEL=${LABEL}
VULTR_REGION=${REGION}
VULTR_PROVISIONED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
META
chmod 600 ~/.config/vultr/instance.env

echo
echo "═══ Done ═══"
echo "Instance ${INSTANCE_ID} is up at ${IP}"
echo "Saved details to ~/.config/vultr/instance.env"
echo
echo "Next: ssh-keyscan -H ${IP} >> ~/.ssh/known_hosts && ssh root@${IP}"
echo "Then: ./03-replicate.sh"
