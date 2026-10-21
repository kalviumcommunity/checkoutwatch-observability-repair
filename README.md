# CheckoutWatch Observability Repair

DevOps Foundation CA 5 starter. Exactly three faults affect container health monitoring, log formatting, and Prometheus collection. Repair the existing scaffold; do not implement a new application. Everything runs locally at ₹0 / $0.

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

Image downloads require internet. Host ports 8080 and 9090 must be available. Stop only your own conflicting services or ask your instructor for help. Missing tools, blocked downloads, and fork restrictions are infrastructure issues, not planted faults. No cloud workaround is required.

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

## Save and submit

Commit and push fixes to `fix/ca5-observability` in **your own public fork**. Do not open an upstream pull request. Submit the PDF specified by your instructor, not a PR, ZIP, or video.

Include genuine before/after evidence for all three tasks, matching your assessment's exact labels, and public fork/branch links. Use `CA5_YourName.pdf`, below 2,000,000 bytes. Follow the assessment for the complete rubric.

After collecting evidence:

```bash
docker compose down
```
