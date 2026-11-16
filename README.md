# CheckoutWatch Observability Repair

DevOps  starter. Exactly three faults affect container health monitoring, log formatting, and Prometheus collection. Repair the existing scaffold; do not implement a new application. Everything runs locally at ₹0 / $0.

## Setup

Install Git, Docker with Compose v2, curl, and jq. Start your Docker engine and check:

```bash
git --version
docker info
docker compose version
curl --version
jq --version
```

Fork https://github.com/kalviumcommunity/checkoutwatch-observability-repair on GitHub, then clone your own public fork:

```bash
git clone https://github.com/<your-username>/checkoutwatch-observability-repair.git
cd checkoutwatch-observability-repair
git checkout -b fix/ca5-observability
docker compose up -d --build
docker compose ps
```

Allow up to 45 seconds for health checks and initial scrapes. Expected original symptoms: the app is **unhealthy**, logs are plain text, and the Prometheus app target is **DOWN**. The app process and monitoring UI still start.

Image downloads require internet. Host ports 8080 and 9090 must be available. Stop only your own conflicting services only if safe to do so. Missing tools, blocked downloads, and fork restrictions are infrastructure issues, not planted faults. No cloud workaround is required.

## Expected contract

- App service `app` listens on container port **8080**.
- `GET /health` returns HTTP 200 and `{"status":"ok"}`. Container probe must reflect this endpoint. This is shallow process liveness, not dependency readiness.
- `GET /checkout` returns HTTP 200.
- `GET /checkout?fail=1` intentionally returns HTTP 500 to generate a traceable failure. Keep this fixture; it is not a fourth bug.
- Each checkout response includes `X-Request-ID`. Start and completion/failure events carry that same UUID.
- Every app event must be one JSON object per line containing `timestamp`, `level`, and `message`. Checkout events also require `request_id`.
- Normal events use `info`. Controlled failure uses `error`. Startup is informational, not a simulated error.
- `/metrics` exposes standard Prometheus text including **`checkout_requests_total`**. It increments once per checkout request, including test failures, but not for health checks or metric scrapes.
- Prometheus collects the app's `/metrics` under job **`checkoutwatch`** using service DNS on the Compose network.
- Prometheus is available at http://localhost:9090/targets and http://localhost:9090/query. Use Table view for instant query results.

A healthy process can return an intentional test error. Docker health status alone does not automatically restart an unhealthy container; restart automation is outside this exercise.

## Investigate and verify

Capture original evidence **before** rebuilding: old container logs may disappear. Inspect the health endpoint, probe state, raw logs, and Targets page:

```bash
curl -i http://localhost:8080/health
docker compose ps
docker inspect --format '{{json .State.Health}}' "$(docker compose ps -q app)"
curl -i http://localhost:8080/checkout
curl -i 'http://localhost:8080/checkout?fail=1'
docker compose logs --no-log-prefix --no-color app
curl -sS http://localhost:8080/metrics
```

Compare runtime observations and configuration with the contract. After source or Dockerfile edits:

```bash
docker compose up -d --build
```

After Prometheus configuration edits:

```bash
docker compose restart prometheus
```

Scrapes run every 5 seconds. Allow two intervals before checking a changed signal. Container health probes also run every 5 seconds.

After logging repairs, generate fresh success/failure requests and inspect them:

```bash
docker compose logs --no-log-prefix --no-color app | jq -c .
docker compose logs --no-log-prefix --no-color app | jq -c 'select(.level == "error")'
docker compose logs --no-log-prefix --no-color app \
  | jq -c --arg id '<actual-failing-request-id>' 'select(.request_id == $id)'
```

Replace the placeholder with the failing response's actual `X-Request-ID`. Never hard-code a sample log line or hide errors. Do not log secrets or sensitive information.

For monitoring proof, evaluate `checkout_requests_total` in Prometheus Table view, generate five requests below, wait two scrape intervals, then evaluate again:

```bash
for i in 1 2 3 4 5; do
  curl -sS http://localhost:8080/checkout
  printf '\n'
done
```

With no other checkout traffic or intervening app restart, the counter increases by five. It resets when the app restarts; do not rebuild midway through this comparison.

## Scope and cleanup

Repair the existing container probe, shared log formatter, and Prometheus scrape configuration. Preserve checkout business logic, controlled failure, request correlation, metric semantics and ports. Compare original and repaired observations; do not replace live signals with constants or disable checks. No Grafana, alert-rule implementation, cloud deployment or real credentials needed.

```bash
docker compose down
```

Remove only your exercise resources.

Repair Report and Submission Guide

1. The three faults and the fixes

Fault 1, container health. The app showed unhealthy. The HEALTHCHECK in Dockerfile requested /healthz, which does not exist and returns 404. Fix: it now requests http://localhost:8080/health.

Fault 2, log formatting. Logs were plain text. The shared log() function in server.js wrote a space separated string. Fix: it now writes JSON.stringify(event) followed by a newline, so each event is one JSON object per line with timestamp, level, message, and request_id on checkout events.

Fault 3, Prometheus collection. The checkoutwatch target was DOWN. prometheus.yml scraped app:8081 but the app listens on 8080. Fix: the target is now app:8080.

Nothing else was changed. Checkout logic, the ?fail=1 failure, X-Request-ID, metric behavior and ports are untouched.

2. Expected result after the fix

docker compose ps shows app healthy. The probe prints probe HTTP 200. Every app log line parses with jq. A ?fail=1 request returns 500 and its error log line carries the same request_id as the X-Request-ID header. Prometheus targets page shows checkoutwatch UP. checkout_requests_total goes up by exactly 5 after 5 checkout requests.

3. Evidence note

The fixes were made by reading the code against the contract. Docker was not available on the machine where the edits were made, so runtime output has not been captured yet. Run the steps below on a machine with Docker (GitHub Codespaces is free and has Docker) and keep your own real output. Do not submit invented output.

4. Steps to produce the evidence (copy and paste)

Before evidence, on the original code:

git checkout main
chmod +x capture-evidence.sh
./capture-evidence.sh before

After evidence, on the fixed code:

docker compose down
git checkout fix/ca5-observability
./capture-evidence.sh after

Manual checks:

docker compose ps
curl -i http://localhost:8080/health
curl -i 'http://localhost:8080/checkout?fail=1'
docker compose logs --no-log-prefix --no-color app | jq -c .

Screenshots to take: Prometheus targets page before (DOWN) and after (UP), docker compose ps before and after, the jq log output, and checkout_requests_total before and after the five requests.

Save evidence in the evidence folder, then:

git add -A
git add -f evidence
git commit -m "docs: add evidence"
git push
docker compose down

5. How to submit

Push branch fix/ca5-observability to your public GitHub repository https://github.com/sanjaipandian-as/checkoutwatch-observability-repair and submit that URL. Include your screenshots or the evidence folder. Open a pull request if your instructor asks for one.

6. Short write-up to paste

I found three independent faults. The Docker HEALTHCHECK probed /healthz, which returns 404, so the container stayed unhealthy; I changed it to the real /health endpoint. The shared log() function wrote plain text; I changed it to JSON.stringify(event) so every event is one JSON object with timestamp, level, message and, for checkout events, request_id. Prometheus scraped app:8081 while the app listens on 8080, so the target was DOWN; I changed it to app:8080.
