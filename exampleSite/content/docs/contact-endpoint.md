---
title: "Contact endpoint"
description: "A reference Cloudflare Worker and KV schema for the interactive/contact shortcode, with the checks the server must do that the browser cannot."
keywords: ["contact", "worker", "kv", "wrangler", "endpoint"]
weight: 100
---

The `interactive/contact` shortcode posts to a JSON endpoint. The
shortcode documents what the server must do; this page is one reference
implementation of a small Cloudflare Worker that does it. Nothing in
Strata ships the worker — the site owns its backend.

The shortcode sends `name`, `email`, `message`, `hp_name` (the
honeypot) and `form_ts` (render time, Unix seconds). The server must
answer with `{"success": true}` on success and `{"success": false,
"error": "…"}` on failure; the client reads that shape.

## Storage layout

Keys sort lexicographically in Workers KV. `contact:{epoch seconds}:
{random UUID}` puts messages in chronological order and stays unique
across workers, so the same shape survives a redeploy or a replica:

```
contact:1759468800:5f6c9a3b-2e7f-4b8c-9a1d-3c8b7e6d5f4a
```

A single key holds one message as a JSON object. Retention is
configured on the namespace: `expirationTtl = 30 * 24 * 60 * 60` for
thirty days, or zero to keep messages forever and clean up manually.

## Worker

```js
export default {
  async fetch(request, env, ctx) {
    if (request.method !== "POST") {
      return json({ success: false, error: "method" }, 405);
    }
    if (!sameOrigin(request, env.ORIGINS)) {
      return json({ success: false, error: "origin" }, 403);
    }
    if ((await readBody(request)).size > 4096) {
      return json({ success: false, error: "size" }, 413);
    }
    const form = await request.formData();
    if (rateLimited(form.get("email") || request.headers.get("CF-Connecting-IP"))) {
      return json({ success: false, error: "rate" }, 429);
    }
    const hp = form.get("hp_name");
    if (hp && String(hp).trim()) {
      return json({ success: true });
    }
    const name = String(form.get("name") || "").trim();
    const email = String(form.get("email") || "").trim();
    const message = String(form.get("message") || "").trim();
    if (!name || !email || !message) {
      return json({ success: false, error: "fields" }, 400);
    }
    if (new TextEncoder().encode(message).length > 1000) {
      return json({ success: false, error: "length" }, 413);
    }
    if (!/^\S+@\S+\.\S+$/.test(email)) {
      return json({ success: false, error: "email" }, 400);
    }
    const ts = form.get("form_ts");
    if (ts) {
      const t = Number(ts);
      const now = Math.floor(Date.now() / 1000);
      if (!Number.isFinite(t) || now - t < 3 || now - t > 7200) {
        return json({ success: false, error: "timestamp" }, 400);
      }
    }
    const key = `contact:${Date.now()}:${crypto.randomUUID()}`;
    await env.MESSAGES.put(key, JSON.stringify({
      name, email, message,
      ip: request.headers.get("CF-Connecting-IP"),
      ts: Math.floor(Date.now() / 1000),
    }));
    await forward(env.NOTIFY_URL, { name, email, message });
    return json({ success: true });
  },
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });
}

async function readBody(request) {
  const buf = await request.arrayBuffer();
  return { size: buf.byteLength };
}

function sameOrigin(request, allowed) {
  const origin = request.headers.get("Origin") || "";
  const secFetch = request.headers.get("Sec-Fetch-Site") || "";
  if (secFetch === "same-origin") return true;
  return allowed.split(",").some((o) => origin === o.trim());
}

function rateLimited(identity) {
  return false;
}

async function forward(url, body) {
  if (!url) return;
  try {
    await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch (_) { /* notify is best-effort */ }
}
```

Rate limiting is left as a stub. Implement it per-identity: keep the
last N timestamps in KV under a `rate:{identity}` key and reject when
any is within the window. Identity should be `email` for authenticated
submissions and the IP for anonymous ones — email is attacker-chosen
and IP can be shared on networks.

## `wrangler.toml`

```toml
name = "contact-endpoint"
main = "src/index.js"
compatibility_date = "2025-01-01"

[vars]
ORIGINS = "https://example.com,https://www.example.com"
NOTIFY_URL = ""

[[kv_namespaces]]
binding = "MESSAGES"
id = "<kv namespace id>"
expiration_ttl = 2592000
```

Create the namespace with `wrangler kv namespace create messages`.
`ORIGINS` is comma-separated because Workers `vars` cannot hold arrays.

## Wiring to the shortcode

```html
{{< interactive/contact action="/api/contact" maxBytes="1000" cooldown="10" minFill="3" >}}
```

Point the endpoint at the Worker with a Cloudflare route
(`/api/contact*` → `contact-endpoint`) or deploy it as a Pages
Function — see [Security](/docs/security/) for the request-count
difference between the two.

## Operational notes

`wrangler tail --filter contact-endpoint` follows production logs in
real time. `wrangler kv key list --prefix contact:` lists every stored
message, and `wrangler kv key delete --prefix contact:` clears the
namespace. All three accept `--remote` for production; without it they
target the local dev environment.

If the site's origin is verified by Cloudflare, add a
`CF-Access-Client-Id` header check to `sameOrigin` for a second pass
that a plain Origin spoof cannot get past. Turnstile or a one-time
token is the escalation for a site the passive layers do not stop.
