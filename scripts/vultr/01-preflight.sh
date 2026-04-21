#!/usr/bin/env bash
# 01-preflight.sh — verify Vultr account state + show what we'd create
# Read-only. Safe to run anytime. Exits 0 on green-light.
set -euo pipefail

source ~/.config/vultr/credentials

REGION="mex"
PLAN="${VULTR_PLAN:-vc2-6c-16gb}"
HOSTNAME="beautycita-mx-1"
LABEL="beautycita-mx-1"

API() { curl -s -H "Authorization: Bearer ${VULTR_API_KEY}" "$@"; }

echo "═══ Account ═══"
API "https://api.vultr.com/v2/account" | python3 -c "
import sys,json
d=json.load(sys.stdin)['account']
print(f'  Name: {d[\"name\"]}')
print(f'  Email: {d[\"email\"]}')
print(f'  Country: {d[\"country\"]}')
print(f'  Balance: \${d[\"balance\"]}  Pending: \${d[\"pending_charges\"]}  Prepay: \${d[\"prepayment_remaining\"]}')
"

echo
echo "═══ Region: ${REGION} ═══"
API "https://api.vultr.com/v2/regions" | python3 -c "
import sys,json
for r in json.load(sys.stdin)['regions']:
    if r['id']=='${REGION}':
        print(f'  {r[\"city\"]} {r[\"country\"]} ({r[\"continent\"]})  options: {\",\".join(r.get(\"options\",[]))}')
"

echo
echo "═══ Plan: ${PLAN} ═══"
API "https://api.vultr.com/v2/plans?type=vc2" | python3 -c "
import sys,json
for p in json.load(sys.stdin)['plans']:
    if p['id']=='${PLAN}':
        avail='AVAILABLE in ${REGION}' if '${REGION}' in p['locations'] else 'NOT AVAILABLE in ${REGION}'
        print(f'  vCPU: {p[\"vcpu_count\"]}  RAM: {p[\"ram\"]/1024:.0f}GB  Disk: {p[\"disk\"]}GB  BW: {p[\"bandwidth\"]/1000:.1f}TB')
        print(f'  Cost: \${p[\"monthly_cost\"]}/mo  {avail}')
"

echo
echo "═══ Existing SSH keys ═══"
API "https://api.vultr.com/v2/ssh-keys" | python3 -c "
import sys,json
keys=json.load(sys.stdin).get('ssh_keys',[])
if not keys: print('  (none uploaded yet — 02-provision.sh will create one)')
else:
    for k in keys: print(f'  {k[\"id\"][:8]}…  {k[\"name\"]}')
"

echo
echo "═══ Existing instances ═══"
API "https://api.vultr.com/v2/instances" | python3 -c "
import sys,json
ins=json.load(sys.stdin).get('instances',[])
if not ins: print('  (none — fresh account)')
else:
    for i in ins: print(f'  {i[\"id\"][:8]}…  {i[\"label\"]:30}  {i[\"region\"]}  {i[\"plan\"]}  status={i[\"status\"]}  \${i[\"main_ip\"]}')
"

echo
echo "═══ Pre-flight summary ═══"
echo "Would create: 1× ${PLAN} in ${REGION} labeled '${LABEL}'"
echo "Estimated monthly cost: \$80 (vc2-6c-16gb) or override with VULTR_PLAN env"
echo
echo "Next step: ./02-provision.sh --apply  (without --apply = dry-run)"
