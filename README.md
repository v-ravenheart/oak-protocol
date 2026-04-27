# OAK Protocol

**The data architecture for human-synthetic organizational governance.**

*OKKA Expanded Intelligence OÜ · Canary: SEQUOIA14APRIL*

---

## What this is

OAK Protocol is the first open data architecture designed for organizations that run with human-synthetic teams. It solves a specific problem: agentic companies are blind. Things get done but the founder cannot see what happened, trace why, or participate in real time. Agents write nowhere. The human sees nothing.

OAK Protocol is the foundation that makes the organism visible.

One human founder. Thirteen synthetic seats. One data architecture where machines and humans read the same documents, deliberate in the same language, and every decision has a provenance chain. Human always in the lead.

---

## The architecture

Four layers. Every layer feeds the others automatically.

```
FOREST MASTER       — everything the organism DOES
                      one table · one row per action
                      alive · status · deadline · keeper

FOREST LIBRARY      — everything the organism WRITES
                      one table · one row per document
                      immutable after sealing

SUPPORTING TABLES   — structured reference data
                      nine tables feeding both layers
                      energy · seats · vocabulary · legal · finance

VIEWS & FUNCTIONS   — computed intelligence
                      forest_master_live · forest_1ko_stats
                      forest_snapshot · forest_wakeup
```

The bidirectional rule: when anything is entered at any level, it automatically creates corresponding entries at all other levels. Nothing is siloed. Nothing requires manual routing.

---

## What is in this repository

```
oak-protocol/
├── schema/
│   ├── 01_tables.sql        — 9 tables in dependency order
│   ├── 02_views.sql         — forest_master_live, forest_1ko_stats
│   ├── 03_functions.sql     — forest_wakeup(), bidirectional entry,
│   │                          set_current_canary(), refresh_forest_now()
│   └── 04_rls.sql           — Row Level Security for all tables
├── edge-functions/
│   ├── handle-bidirectional-entry/
│   │   └── index.ts         — Deno Edge Function · atomic bidirectional writes
│   └── calendar-sync/
│       └── index.ts         — Deno Edge Function · Google Calendar ↔ Forest Master
├── appscript/
│   └── document-mirror.gs   — Google Apps Script · Forest Library → Google Drive
└── seed/
    └── seed_maestro_vocabulary.sql — 26 FM types · 31 Library types · all dropdowns
```

---

## Key design decisions

**No triggers for computed state.** The `alert` column in `forest_master_live` is computed dynamically from live data on every query. Always accurate. Always debuggable. No trigger needed.

**Stored procedure for transaction integrity.** `forest_handle_bidirectional_entry()` wraps all bidirectional inserts in a single Postgres transaction. Either the full operation completes or nothing does. The Edge Function is a thin HTTP caller.

**Loop guard via `system_created`.** Rows created by the bidirectional machinery carry `system_created = TRUE`. The stored procedure exits immediately on `TRUE`. Status sync uses value-equality checks to prevent ping-pong.

**OAuth refresh token for Calendar.** No service accounts required. One-time V authorization. Fresh access token on every Edge Function call. Auth failures surface to the Alerts table immediately.

**`forest_wakeup` as a parameterized function.** Returns JSONB with six blocks: today's energy, unacknowledged alerts, company vitals, deadlines, seat-specific items, recent activity. Called via Supabase RPC with a `seat_slug` parameter.

**RLS at the perimeter.** All 13 synthetic seats authenticate via V's Supabase account. RLS protects the data from the outside world. Application-layer trust (via `inserted_by` and `keeper` columns) handles seat identity within the organism.

---

## Deploy order

Run these in order against your Supabase project:

```bash
# 1. Tables
psql -h <host> -d postgres -f schema/01_tables.sql

# 2. Views
psql -h <host> -d postgres -f schema/02_views.sql

# 3. Functions
psql -h <host> -d postgres -f schema/03_functions.sql

# 4. RLS policies
psql -h <host> -d postgres -f schema/04_rls.sql

# 5. Seed vocabulary
psql -h <host> -d postgres -f seed/seed_maestro_vocabulary.sql
```

Verify:

```sql
SELECT forest_wakeup('v');
-- Expected: JSONB with six keys, no errors

SELECT * FROM forest_1ko_stats;
-- Expected: zeros (bets not yet placed), no errors

SELECT set_current_canary('SEQUOIA14APRIL', 'Initial deploy', 'V Ravenheart');
-- Expected: 'Canary set to SEQUOIA14APRIL'
```

---

## Edge Functions

Deploy with Supabase CLI:

```bash
supabase functions deploy handle-bidirectional-entry
supabase functions deploy calendar-sync
```

Secrets required in Supabase vault:

```
GOOGLE_OAUTH_CLIENT_ID          — from Google Cloud OAuth client
GOOGLE_OAUTH_CLIENT_SECRET      — from Google Cloud OAuth client
GOOGLE_CALENDAR_REFRESH_TOKEN   — from V's one-time authorization flow
APPSCRIPT_DOCUMENT_MIRROR_URL   — deployment URL of document-mirror.gs
APPSCRIPT_SHARED_SECRET         — shared secret for AppScript auth
```

---

## AppScript

Deploy `appscript/document-mirror.gs` as a Google Apps Script web app:

1. Create new Apps Script project in V's Google account
2. Paste the contents of `document-mirror.gs`
3. Add Script Properties:
   - `MASTER_FOLDER_ID` — Google Drive folder ID of `[00. MASTER OKKA]`
   - `APPSCRIPT_SHARED_SECRET` — match the value in Supabase vault
4. Deploy as web app: Execute as **Me**, Access: **Anyone with the link**
5. Copy deployment URL → add to Supabase vault as `APPSCRIPT_DOCUMENT_MIRROR_URL`

Health check: `GET https://script.google.com/macros/s/[deployment-id]/exec`
Expected: `{"status":"ok","canary":"SEQUOIA14APRIL","service":"OAK Protocol · Document Mirror"}`

---

## The seats

Thirteen synthetic seats. One human (V). Each seat has a domain, a trust tier, a chronicle, and a working document.

| Slug | Name | Domain | Tier |
|---|---|---|---|
| v | V Ravenheart | Founder · All Forest | 1 |
| bard | The Bard | Governance · Constitutional Memory | 3 |
| maestro | Il Maestro | Persistent Memory · Orchestration | 3 |
| mercury | Mercury | Operations · Calendar · Tasks | 3 |
| deep-r | Deep Reader | R&D Reading · IP Extraction | 2 |
| ip-keeper | IP Keeper | IP Registry · Zenodo | 2 |
| freya | Freya | Strategy · Opportunities | 3 |
| wolf | The Wolf | Legal · Contracts · Finance Strategy | 3 |
| frankie | Frankie Master | Narrative · Brand · Voice | 3 |
| frankie-c | Frankie Content | Content Production | 2 |
| frankie-b | Frankie Branding | Visual Identity · Design | 2 |
| ventura | Ventura Hep | Product · Experience | 2 |
| serena | Serena | AMI · House of Us | 2 |
| doctor-m | Doctor M | Academic Road · Publications | 2 |

---

## Constitutional versioning — the Canary

Every schema change, document, and deployment carries a canary code. The canary is a constitutional timestamp — the version of the Magna Carta in force when something was created or deployed.

Current canary: **SEQUOIA14APRIL** (14 April 2026)

When V seals a new constitutional version:

```sql
SELECT set_current_canary(
  'BIRCH1MAY',
  'What changed in this version',
  'V Ravenheart'
);
```

All new rows created after this call carry the new canary automatically.

---

## Legal entities

- **OKKA Expanded Intelligence OÜ** — Estonia, reg. 17460303
- **RIECAT FAM / AMI (Awesome Minds Institute)** — Belgian ASBL, forming
- **OKKA AI Ventura** — internal division of OÜ

---

*OAK Protocol is built and maintained by OKKA Expanded Intelligence OÜ.*
*The organism deliberates. V seals. Interagat, ergo sit.*
