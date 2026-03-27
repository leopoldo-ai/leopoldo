---
name: clients
version: 1.0.0
description: Client CRM for Leopoldo. List, manage, communicate with, and monitor clients from Claude Code. Use with /clients command.
skillos:
  layer: core
  category: meta
  pack: null
  requires:
    hard: []
    soft: []
  provides: ["client-management", "crm"]
  triggers: ["/clients"]
  config: {}
---

# Leopoldo Client Manager

CRM interface for managing Leopoldo Full clients. All operations go through the Leopoldo backend API.

## Configuration

Read credentials from environment:
- `LEOPOLDO_ADMIN_KEY`: admin API key (from .env or environment)
- `LEOPOLDO_API_URL`: backend URL (default: `https://leopoldo-api-production.up.railway.app`)

All API calls use header `X-Admin-Key: {LEOPOLDO_ADMIN_KEY}`.

## Commands

### /clients

List all clients with licensing status.

**API call:** `GET {api_url}/api/clients`

**Output format:**

| Client | Plan | Domains | Expires | Status |
|--------|------|---------|---------|--------|
| acme-corp | full | finance, consulting | 2027-03-27 | 🟢 |
| beta-fund | full | finance | 2026-04-15 | 🟡 |
| old-client | full | dev | 2026-03-01 | 🔴 |

Status logic:
- 🟢 Active: expires > 30 days from now
- 🟡 Expiring: expires within 30 days
- 🔴 Expired: past expiry date or inactive

### /clients {id}

Show client detail with recent activity.

**API call:** `GET {api_url}/api/clients/{id}`

**Output format:**

**Client: Acme Corp** (acme-corp)
- Email: john@acme.com
- Plan: full
- Domains: investment-core, deal-engine
- Expires: 2027-03-27 (365 days) 🟢
- Version: 1.0.0
- Last update check: 2026-03-25
- Notes: Key finance client

**Recent Actions:**
| Date | Action | Details |
|------|--------|---------|
| 2026-03-27 | registered | domains: investment-core, deal-engine |
| 2026-03-25 | update_checked | updates_found: 0 |

**Communications:**
| Date | Type | Subject |
|------|------|---------|
| 2026-03-27 | email | Welcome to Leopoldo |

### /clients {id} email "subject" "body"

Send a custom email to the client via Resend.

**API call:** `POST {api_url}/api/clients/{id}/communicate`
**Body:** `{"template": "custom", "type": "email", "subject": "{subject}", "body": "{body}"}`

Confirm before sending: "Send email to {email} with subject '{subject}'? [y/N]"

### /clients {id} renew

Extend license by 12 months.

**API call:** `POST {api_url}/api/clients/{id}/renew`
**Body:** `{"months": 12}`

Show: "License extended to {new_expires}."

### /clients {id} revoke

Disable client access.

**API call:** `POST {api_url}/api/clients/{id}/revoke`

Confirm before revoking: "This will disable {id}'s API key. Proceed? [y/N]"

### /clients {id} note "text"

Save an internal note (not emailed).

**API call:** `POST {api_url}/api/clients/{id}/communicate`
**Body:** `{"template": "custom", "type": "note", "subject": "Internal note", "body": "{text}"}`

### /clients stats

Show aggregate statistics.

**API call:** `GET {api_url}/api/clients/stats`

**Output format:**

| Metric | Value |
|--------|-------|
| Total clients | 12 |
| Active | 10 🟢 |
| Expiring (30d) | 2 🟡 |
| Expired | 1 🔴 |
| Updates served | 45 |
| Last registration | 2026-03-27 |

## API Authentication

All requests require the `X-Admin-Key` header. Read the key from:
1. Environment variable `LEOPOLDO_ADMIN_KEY`
2. `.env` file in project root (grep for LEOPOLDO_ADMIN_KEY)

If neither is found, show: "Admin key not configured. Set LEOPOLDO_ADMIN_KEY in your environment."

## Error Handling

| Error | Message |
|-------|---------|
| No admin key | "Admin key not configured. Set LEOPOLDO_ADMIN_KEY in your environment." |
| Network error | "Could not reach Leopoldo backend. Check your connection." |
| 401 | "Invalid admin key." |
| 404 | "Client not found." |

## Rules

- This skill is studio-only (never distributed to clients)
- All data comes from the backend API, not from local files
- Confirm before sending emails or revoking access
- Use traffic lights for status visualization
- Use WebFetch for API calls
