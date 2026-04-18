# Fax Your Rep — Sender Verification & Rate Limiting (Design)

Card: Kanboard #130 — *Design sender verification and rate limiting*.
Status: research / decomposition draft. Author decisions still required on items marked **OPEN**.

## 1. Rhetorical principles

The verification UX is the argument. Every choice in this design is downstream of these principles:

1. **We verify constituency, not age.** A constituent is a person whose vote can affect a particular legislator. That is the only fact relevant to a fax. Age is not.
2. **We verify the bare minimum that makes the fax credible to its recipient** — not what makes a regulator comfortable. A working email and a self-attested district address are sufficient because that is what an honest letter has always required.
3. **What we collect is public.** Every field the sender provides is enumerated on the form, in plain English, with the retention period printed beside it. No analytics SDKs, no fingerprinting libraries, no third-party JS.
4. **What we refuse to collect is also public.** A short list — date of birth, government ID, biometric data, "age signal," device attestation — is printed on the form alongside the fields we do collect, with citations to the AB 1043 sections that would require them in a "compliant" implementation.
5. **Anti-abuse is honest, not silent.** When a send is blocked or rate-limited, the user sees the rule that blocked them and the page that defines the rule. No silent shadow-banning.

These principles drive every section below. If a future implementation pull request relaxes one of them, that PR is the place to argue the relaxation, not this doc.

## 2. What gets collected (data model)

The verification flow stores exactly the following per *send attempt*:

| Field | Source | Retention | Purpose |
| --- | --- | --- | --- |
| `email` | user-entered | 30 days after last send | dedup, rate limit, reachability |
| `email_verified_at` | server timestamp | 30 days | proves the email round-tripped |
| `street_address` | user-entered | **discarded after geocode** | input only; never persisted past the request |
| `district_key` | derived from address via Census geocoder | 30 days | rate limit dedup; identifies the constituency |
| `state_abbr` | derived | 30 days | bill selection |
| `ip_address` | request header | 7 days, then truncated to /24 | abuse heuristics only |
| `user_agent` | request header | 7 days | abuse heuristics only |
| `sent_rep_ids[]` | derived | 30 days | one-fax-per-rep-per-week ledger |
| `fax_id` | from Telnyx response | 30 days | reconciliation with cost log |

After the retention window, rows are deleted, not anonymised. The retention page on `agelesslinux.org` publishes the schema verbatim and the cron job that performs the deletes.

**Not collected:** date of birth, year of birth, age bracket, government identifier, biometric, device fingerprint, geolocation finer than the street address the user typed, browser cookies beyond a single first-party session id.

## 3. Verification flow (happy path)

```
[1] User enters: email, street address, persona choice
       │
[2] Server geocodes address (existing lookup.py, Census Bureau)
    └─ if no district → show "address not found" + link to manual fallback
       │
[3] Server creates pending_send row, sends magic-link email
    └─ link is a single-use HMAC token, 30 min TTL
       │
[4] User clicks link in email
    └─ server marks email_verified_at, returns to the preview screen
       │
[5] Server runs ledger checks:
       a. has this (email, rep_id, week) already been sent? → block, show ledger entry
       b. has this (ip /24, week) sent > N to different reps? → soft-flag, queue
       c. has this (email_domain, week) sent > M? → soft-flag, queue
       │
[6] User reviews PDF preview, clicks "Send fax"
    └─ server posts to Telnyx, logs to fax_costs.json AND ledger
       │
[7] Sender lands on a transparency page showing:
       - the fax_id
       - the rate-limit clock for that rep
       - a permalink to the public ledger row (district + week + rep, no PII)
```

## 4. Architecture options (OPEN)

Three viable shapes. Card #133 has already declared "static site with serverless backend," which biases toward Option A but does not lock it in.

### Option A — Static site + serverless functions (Cloudflare Workers / Vercel / AWS Lambda)

- **Storage:** Cloudflare D1 (SQLite at the edge), Turso, or Vercel Postgres.
- **Email:** Resend, Postmark, or AWS SES via Worker.
- **Pros:** Fits card #133 directive; near-zero idle cost; HTTPS + DDoS handled by the platform; easy to rotate keys.
- **Cons:** Worker runtime ≠ Python — fax.py / lookup.py would either need to be ported (small, both are pure-stdlib + reportlab + requests) or invoked via a separate "send worker" on a tiny Python host. Telnyx response webhook and reportlab PDF rendering both want a real Python process.
- **Pragmatic shape:** Worker handles HTTP (form, email, ledger, rate limit) and POSTs the validated request to a small Python service (Fly.io, Railway, or a $5 VPS) that runs `fax.py`. Two trust zones, narrow API between them.

### Option B — Single Python service (FastAPI on a VPS or Fly.io)

- **Storage:** local SQLite file.
- **Email:** Postmark / SES via SMTP.
- **Pros:** One language, one repo, fax.py imported directly, no IPC. Cheapest and simplest to reason about. Easiest for the project's transparency goals — every line is in `agelesslinux/`.
- **Cons:** Static site directive in card #133 means an additional CORS-enabled API surface. Single host = single point of failure (acceptable for civil-disobedience tool with no SLA).
- **Pragmatic shape:** `agelesslinux.org` posts directly to `fax.agelesslinux.org` (the FastAPI app). Static frontend, dynamic backend, both first-party.

### Option C — Hybrid: static frontend, serverless edge for HTTP, Python worker for fax

- **HTTP edge:** Cloudflare Worker for form receive, magic-link email, ledger writes (D1).
- **Send worker:** Python service polls a queue (D1 row, SQS, or Cloudflare Queues), generates PDFs, calls Telnyx.
- **Pros:** Combines edge-grade abuse handling with Python's PDF/Telnyx ergonomics. Strongest separation of concerns.
- **Cons:** Most moving parts. Two deployment targets, one queue, two on-call surfaces.

**Recommendation (subject to author):** **Option B**. The project values legibility over scale; one Python service that imports the existing modules directly is the smallest and most honest implementation. Option A becomes attractive only if traffic exceeds what a $5–10 VPS can handle, at which point the migration is cheap (the Worker would proxy to the same `fax.py`).

## 5. Email verification — magic link

- 32-byte random token, hex-encoded, single use, 30 min TTL.
- Token stored as `sha256(token)` server-side; raw token only in the email link.
- Link format: `https://fax.agelesslinux.org/v/{token}`.
- On click, server marks `email_verified_at = now()`, redirects to the preview/send screen with a session cookie (HMAC-signed, 24 h TTL).
- Bounce handling: SES/Postmark bounce webhook deletes the pending row and the address is added to a 30-day suppression list (so a typo'd address doesn't get re-sent every refresh).
- **No password, no account.** Each fax is a fresh round-trip. Sessions exist only to span the click → preview → send sequence within one browser visit.

**Email copy (draft):**

> Subject: Click to confirm — your fax to {legislator_name}
>
> A fax to {legislator_name} ({district}) is queued from this email address. Click the link below within 30 minutes to send it. If you didn't start this, ignore the email — nothing will be sent.
>
> {link}
>
> We verified that this address resolves to a district. We did not verify your age. We will never verify your age. We retain this email for 30 days for the rate-limit clock; after that, the row is deleted, not anonymised.

## 6. Address self-certification

The Census geocoder (already wired in `lookup.py`) returns one or more matches. The flow:

1. User types an address.
2. Server geocodes; if exactly one match → use it; if multiple → show the user the matches and ask them to pick one; if none → show error with link to a manual rep-picker fallback.
3. Server displays the geocoded address back to the user with a checkbox: *"I attest that I live at the address above and am eligible to communicate with the legislators for this district."*
4. The checkbox is required to proceed. The attestation text is logged with `email_verified_at` (one timestamp; the attestation is by reference, the literal text is in the public design doc, not duplicated per-row).

The full street address is **not** persisted past geocode; only the district identifiers are kept (see § 2). This is the single most important data-minimisation choice in the design.

## 7. Rate limit — one fax per rep per sender per week

- Ledger table: `sent(email_hash, rep_id, week_iso, fax_id, sent_at)`.
- `email_hash = sha256(lowercase(email) + server_secret)`. Pepper prevents rainbow-table re-identification of the ledger if it is ever leaked.
- `week_iso = ISO 8601 week, US/Pacific` (Monday-anchored). Pacific because the primary target is California.
- Pre-send check: `SELECT 1 FROM sent WHERE email_hash=? AND rep_id=? AND week_iso=?` → if hit, block with a message that names the legislator, the previous `fax_id`, and the date the clock resets.
- Post-send write: row inserted in the same transaction as the Telnyx call's success acknowledgement.
- **No exception path.** Not even for the BDFL. The transparency page documents this.

## 8. IP + email pattern tracking (anti-abuse)

Heuristics, not hard rules. They feed a manual review queue, not silent blocks.

| Signal | Threshold (default, OPEN) | Action |
| --- | --- | --- |
| > 5 distinct emails verified from same /24 in 24 h | warn | queue further sends from that /24 for review |
| > 20 sends from same email domain in 7 d (excluding gmail, outlook, yahoo, icloud, proton, fastmail, hey) | warn | queue further sends from that domain for review |
| Email domain MX lookup fails | hard block | refuse to send verification email |
| Address geocodes to a non-residential ZIP+4 (commercial mail receiving agency) | warn | proceed but tag the row |
| Same fax_to_number receiving > 50 sends/day across all senders | inform | rotate Telnyx outbound caller-ID, do not block |

**No CAPTCHA.** A CAPTCHA imposes the same kind of identity-checkpoint burden the project objects to. If volume exceeds what these heuristics handle, escalate to a slow-mode (1 send / IP / 5 min) before considering CAPTCHA.

The review queue is a flat HTML page on the admin side. Items auto-release after 48 h if nobody acts.

## 9. Public transparency surfaces

These pages must ship with the backend, not as a follow-up:

- `/verification` — the rhetorical statement, the data table from § 2, the retention cron schedule, links to `fax.py` and `lookup.py`.
- `/ledger` — public, append-only, no PII. Columns: `week`, `state`, `district`, `rep_name`, `count`, `last_fax_id`. Useful for journalists and for the senders themselves to see they are not alone.
- `/rate-limit` — explains the one-per-rep-per-week rule and why.
- `/refused-fields` — the list of things we will not collect, with the AB 1043 § 1798.500–504 citations that would require them.

## 10. Open decisions for the author

1. **Architecture:** Option A / B / C above. (Recommendation: B.)
2. **Email provider:** Postmark (transactional reputation), SES (cheapest), or Resend (newest, easiest API). Pick one before implementation.
3. **DB choice for Option B:** SQLite file vs. Postgres. SQLite is sufficient at expected volumes; Postgres only if you want hosted backups out of the box.
4. **Server secret rotation:** how often, and what's the migration path for `email_hash` peppered values? Default: never rotate; bake the project's first secret into the design and accept that ledger continuity outlasts secret rotation.
5. **Suppression list duration after bounce:** 30 days (default) vs. permanent.
6. **ZIP+4 commercial-receiver flag:** USPS database is not free at low volumes. Skip this signal v1, add later?
7. **Pacific week vs. legislator's local week:** Pacific is simpler; per-legislator local week is more honest. Default: Pacific, document the choice.
8. **Admin review queue UI:** flat HTML with HTTP basic auth, or a real auth flow? Flat HTML is fine for v1.

## 11. Proposed implementation sub-tasks

If this design is accepted as-is, the implementation work decomposes into the following Kanboard cards, each medium scope:

1. **#130-A — Verification backend skeleton.** FastAPI (or Worker) project layout, SQLite schema, session cookies, env-var config, deploy target. *Effort: 1 session.*
2. **#130-B — Magic-link email flow.** Provider integration, send + verify endpoints, bounce webhook, suppression list. *Effort: 1 session.*
3. **#130-C — Address self-certification glue.** Wire existing `lookup.py` into the form post; multi-match disambiguation UI hook (frontend lives in #133, backend endpoint here). *Effort: 0.5 session.*
4. **#130-D — Rate-limit ledger + pre-send check.** Schema, hashed-email pepper, week computation, block-with-explanation response shape. *Effort: 1 session.*
5. **#130-E — Abuse heuristics + review queue.** The four signals from § 8, queue table, admin HTML page. *Effort: 1.5 sessions.*
6. **#130-F — Transparency pages.** `/verification`, `/ledger`, `/rate-limit`, `/refused-fields` — content-only, but each cites concrete schema/code. *Effort: 1 session.*
7. **#130-G — Retention cron.** Daily delete job, public log of what it deleted. *Effort: 0.5 session.*

Total: ~6.5 sessions for a complete, transparent, Option-B implementation. Can ship in increments: A+B+C+D is a minimum-viable, principled send path; E+F+G harden it.

## 12. Out of scope

- The frontend HTML/CSS form (card #133).
- PDF generation and Telnyx send (already shipped in `fax.py`).
- Address-to-legislator pipeline (already shipped in `lookup.py`).
- Federal legislator coverage (43.9% have any fax — see `FAX_COVERAGE_REPORT.md`). The verification system does not solve this; it just refuses to send if `lookup.py` returns no fax number.
- Authentication for legislators or staff (irrelevant — this is a public send-only system).
