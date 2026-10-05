#!/usr/bin/env bash
# Security checks and the end-to-end incident.
# Needs: kubectl -n agentgateway-system port-forward svc/agentgateway-proxy 8080:80
set -uo pipefail
GW_LOCAL=${GW_LOCAL:-http://localhost:8080}

echo "1. No token to the Troubleshooter (expect 401):"
curl -s -o /dev/null -w '   %{http_code}\n' "$GW_LOCAL/a2a/ops/ekstroubleshooter/" -H content-type:application/json -d '{}'

TOKEN=$(kubectl -n ops-callers create token incident-intake --duration 1h)
echo "2. Valid token, wrong caller (expect 403):"
curl -s -o /dev/null -w '   %{http_code}\n' "$GW_LOCAL/a2a/ops/ekstroubleshooter/" \
  -H "Authorization: Bearer $TOKEN" -H content-type:application/json -d '{}'

echo "3. No token to the On-call route (expect 401):"
curl -s -o /dev/null -w '   %{http_code}\n' "$GW_LOCAL/a2a/ops/platformoncall/" -H content-type:application/json -d '{}'

echo "4. End-to-end incident (takes 30-90 s):"
curl -s --max-time 300 "$GW_LOCAL/a2a/ops/platformoncall/" \
  -H "Authorization: Bearer $TOKEN" -H content-type:application/json -d '{
  "jsonrpc": "2.0", "id": "inc-1", "method": "message/send",
  "params": {"message": {"role": "user", "kind": "message", "messageId": "inc-1",
    "parts": [{"kind": "text", "text": "Alarm: checkout pods in namespace shop are in CrashLoopBackOff. Find the root cause and propose a fix."}]}}
}' | jq -r '.result.artifacts[]?.parts[]?.text // .result.status.message.parts[]?.text // .'

echo
echo "Gateway hops in the last 5 minutes:"
kubectl -n agentgateway-system logs deploy/agentgateway-proxy --since=5m 2>/dev/null \
  | grep -oE 'route=[^ ]+|http.status=[0-9]+|a2a.task.state=[^ ]+' | paste - - - | tail -8
