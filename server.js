'use strict';

const express = require('express');
const { randomUUID } = require('node:crypto');
const { Registry, Counter } = require('prom-client');

const app = express();
const registry = new Registry();
const requests = new Counter({
  name: 'checkout_requests_total',
  help: 'Number of checkout requests, including controlled test failures.',
  registers: [registry],
});
requests.inc(0);

function log(event) {
  process.stdout.write(`${event.timestamp} ${event.level} ${event.message} ${event.request_id || '-'}\n`);
}

function event(level, message, requestId) {
  const entry = { timestamp: new Date().toISOString(), level, message };
  if (requestId) entry.request_id = requestId;
  log(entry);
}

app.get('/', (_req, res) => res.send('CheckoutWatch is running\n'));
app.get('/health', (_req, res) => res.json({ status: 'ok' }));
app.get('/checkout', (req, res) => {
  const id = randomUUID();
  res.set('X-Request-ID', id);
  requests.inc();
  event('info', 'checkout.started', id);
  if (req.query.fail === '1') {
    event('error', 'checkout.failed: controlled test failure', id);
    return res.status(500).json({ status: 'failed', reason: 'controlled test failure' });
  }
  event('info', 'checkout.completed', id);
  return res.json({ status: 'complete' });
});
app.get('/metrics', async (_req, res, next) => {
  try {
    res.type(registry.contentType).send(await registry.metrics());
  } catch (error) {
    next(error);
  }
});

app.listen(8080, '0.0.0.0', () => event('info', 'checkoutwatch.started'));
