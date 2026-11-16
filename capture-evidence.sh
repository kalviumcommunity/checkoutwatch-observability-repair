#!/usr/bin/env bash
# Captures real before/after evidence into ./evidence/. Usage:
#   ./capture-evidence.sh before   (run on the ORIGINAL code: git stash or checkout main~)
#   ./capture-evidence.sh after    (run on the FIXED code)
set -u
phase="${1:?usage: $0 before|after}"
d="evidence/$phase"; mkdir -p "$d"
docker compose up -d --build >"$d/00-up.txt" 2>&1
echo "waiting 45s for health checks and scrapes..."; sleep 45
docker compose ps >"$d/01-compose-ps.txt" 2>&1
docker inspect --format '{{json .State.Health}}' "$(docker compose ps -q app)" | jq . >"$d/02-health-state.json" 2>&1
{ curl -i http://localhost:8080/health; } >"$d/03-health.txt" 2>&1
{ curl -i http://localhost:8080/checkout; echo; curl -i 'http://localhost:8080/checkout?fail=1'; } >"$d/04-checkout.txt" 2>&1
docker compose logs --no-log-prefix --no-color app >"$d/05-app-logs.txt" 2>&1
curl -sS http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job:.labels.job, scrapeUrl, health, lastError}' >"$d/06-prom-targets.json" 2>&1
if [ "$phase" = after ]; then
  docker compose logs --no-log-prefix --no-color app | jq -c . >"$d/07-logs-jq.txt" 2>&1
  docker compose logs --no-log-prefix --no-color app | jq -c 'select(.level=="error")' >"$d/08-error-logs.txt" 2>&1
  id=$(curl -s -D - -o /dev/null 'http://localhost:8080/checkout?fail=1' | tr -d '\r' | awk -F': ' 'tolower($1)=="x-request-id"{print $2}')
  echo "$id" >"$d/09-failing-request-id.txt"
  sleep 6
  docker compose logs --no-log-prefix --no-color app | jq -c --arg id "$id" 'select(.request_id==$id)' >"$d/10-trace-by-request-id.txt" 2>&1
  q(){ curl -sS --data-urlencode 'query=checkout_requests_total' http://localhost:9090/api/v1/query | jq -r '.data.result[0].value[1]'; }
  q >"$d/11-counter-before.txt"
  for i in 1 2 3 4 5; do curl -sS http://localhost:8080/checkout; echo; done >"$d/12-five-requests.txt"
  sleep 12
  q >"$d/13-counter-after.txt"
  echo "counter: $(cat "$d/11-counter-before.txt") -> $(cat "$d/13-counter-after.txt") (expect +5)"
fi
echo "Saved to $d. Now take screenshots: http://localhost:9090/targets"
