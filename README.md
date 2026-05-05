> **IP Notice:** This repository is the intellectual
> property of OKKA Expanded Intelligence OÜ
> (reg. 17460303, Estonia). All rights reserved.
> Available for review and reference only.
> Commercial use requires written permission.
> See COPYRIGHT file for full terms.

---

# The OAK Protocol
## Business governance infrastructure for
## human-synthetic organisations

Four problems make AI collaboration fail in practice.

**Problem 1 — AI agents forget everything
between sessions.**
Memory lives in the chat window. When the session
ends, it is gone. The OAK Protocol solves this with
a single typed table (Forest Master) and a document
library (Forest Library) that any seat reads at
session start and writes to at session end. Memory
lives in the organism, not in the conversation.

**Problem 2 — Multi-agent frameworks are built
for technical tasks, not business governance.**
Coding pipelines and API automation are solved
problems. Legal decisions, financial architecture,
IP management, content strategy, and constitutional
governance are not. The OAK Protocol is the first
governance architecture designed for a synthetic
council running a real business — with defined seats,
trust tiers, domain ownership, and constitutional rules.

**Problem 3 — There is no infrastructure for real
human-synthetic deliberation.**
Most agentic systems delegate tasks to agents and
collect outputs. The Round Table Protocol does
something different: it runs structured deliberation
sessions where multiple AI seats and the human
participate simultaneously, each contributing domain
knowledge in sequence, with real organisational data
feeding the session in real time. The output is a
sealed decision that enters the organism's permanent
record. Agents do not lose context at the end of the
session — they write what happened to the Forest
Library and read it back at the next session.
This is not delegation. It is deliberation.

**Problem 4 — Humans cannot see what agents are doing.**
Every existing multi-agent framework requires a
technical operator to relay information between the
system and the human. The OAK Protocol eliminates
the relay entirely. Agents write to the same database
humans read from. Humans write documents agents access
directly. One platform. Real-time. No translation
layer. No human bottleneck.

The combination — persistent memory across sessions,
business governance architecture, real-time
human-synthetic deliberation with live data, and
shared human-agent readability on one platform —
is what makes this different.

---

## What is in this repository

- The Forest Master schema — the single typed table
  that holds every action, decision, contract,
  publication, and record the organism produces
- The Round Table Protocol — the structured
  deliberation framework for human-synthetic sessions
- The Magna Carta template — the constitutional
  document format inherited by every entity in
  the organism
- The Forest Library schema — the document layer
  where chronicles, legal records, and governance
  entries live
- The OAK document architecture — the full
  specification of how the organism's memory system
  works

---

## Status

Running in production since March 2026.
13 differentiated AI seats operating across legal,
financial, strategic, brand, academic, and product
domains.

---

## Author and IP

**Founder:** Bibiana Xausa Bosak
**ORCID:** 0009-0006-9741-549X
**Legal entity:** OKKA Expanded Intelligence OÜ
**Registration:** 17460303 · Estonia
**Contact:** its.v@okka.ai

**Published research:**
Round Table Protocol · DOI: 10.5281/zenodo.19222206
OKKA Expanded Intelligence Programme ·
DOI: 10.5281/zenodo.19086615

---

## Licence

All rights reserved. See COPYRIGHT file.
Commercial use requires written permission from
OKKA Expanded Intelligence OÜ.
Academic and non-commercial research use permitted
with full attribution.

---

---

## Technical reference

### The architecture

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
                      get_dashboard() · get_content_metrics()
```

The bidirectional rule: when anything is entered at any level, it automatically creates corresponding entries at all other levels. Nothing is siloed. Nothing requires manual routing.

---

### Repository structure

```
oak-protocol/
├── schema/
│   ├── 01_tables.sql            — 15 tables in dependency order
│   ├── 02_views.sql             — forest_master_live, forest_1ko_stats
│   ├── 03_functions.sql         — forest_wakeup(), bidirectional entry,
│   │                              set_current_canary(), refresh_forest_now()
│   ├── 04_rls.sql               — Row Level Security for all tables
│   ├── 05_supporting_tables.sql — fact_sheet, entity_registry, ip_assets,
│   │                              legal_table, finance, content_pipeline
│   └── 06_dashboard_layer.sql   — all 7 dashboards: column additions,
│                                  forest_1ko_stats rebuild, get_content_metrics(),
│                                  forest_snapshot, get_dashboard()
├── edge-functions/
│   ├── handle-bidirectional-entry/
│   │   └── index.ts             — Deno Edge Function · atomic bidirectional writes
│   └── calendar-sync/
│       └── index.ts             — Deno Edge Function · Google Calendar ↔ Forest Master
├── appscript/
│   └── document-mirror.gs       — Google Apps Script · Forest Library → Google Drive
└── seed/
    └── seed_maestro_vocabulary.sql — FM types · Library types · all dropdowns
```

---

### Deploy order

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

# 5. Supporting tables
psql -h <host> -d postgres -f schema/05_supporting_tables.sql

# 6. Dashboard layer
psql -h <host> -d postgres -f schema/06_dashboard_layer.sql

# 7. Seed vocabulary
psql -h <host> -d postgres -f seed/seed_maestro_vocabulary.sql
```

Verify:

```sql
SELECT forest_wakeup('v');
-- Expected: JSONB with six keys, no errors

SELECT * FROM forest_1ko_stats;
-- Expected: zeros (bets not yet placed), no errors

SELECT get_dashboard('wakeup', 'v');
-- Expected: energy + snapshot + deadlines JSONB

SELECT set_current_canary('SEQUOIA14APRIL', 'Initial deploy', 'V Ravenheart');
-- Expected: 'Canary set to SEQUOIA14APRIL'
```

---

### Edge Functions

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

### AppScript

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

### Key design decisions

**No triggers for computed state.** The `alert` column in `forest_master_live` is computed dynamically from live data on every query. Always accurate. Always debuggable. No trigger needed.

**Stored procedure for transaction integrity.** `forest_handle_bidirectional_entry()` wraps all bidirectional inserts in a single Postgres transaction. Either the full operation completes or nothing does. The Edge Function is a thin HTTP caller.

**Loop guard via `system_created`.** Rows created by the bidirectional machinery carry `system_created = TRUE`. The stored procedure exits immediately on `TRUE`. Status sync uses value-equality checks to prevent ping-pong.

**OAuth refresh token for Calendar.** No service accounts required. One-time V authorization. Fresh access token on every Edge Function call. Auth failures surface to the Alerts table immediately.

**`forest_wakeup` as a parameterized function.** Returns JSONB with six blocks: today's energy, unacknowledged alerts, company vitals, deadlines, seat-specific items, recent activity. Called via Supabase RPC with a `seat_slug` parameter.

**RLS at the perimeter.** All 13 synthetic seats authenticate via V's Supabase account. RLS protects the data from the outside world. Application-layer trust (via `inserted_by` and `keeper` columns) handles seat identity within the organism.

---

### The seats

Thirteen synthetic seats. One human (V). Each seat has a domain, a trust tier, a chronicle, and a working document.

| Slug | Name | Domain | Tier |
|---|---|---|---|
| v | V Ravenheart | Founder · All Forest | 1 |
| the-bard | The Bard | Governance · Constitutional Memory | 3 |
| il-maestro | Il Maestro | Persistent Memory · Orchestration | 3 |
| mercury | Mercury | Operations · Calendar · Tasks | 3 |
| deep-reader | Deep Reader | R&D Reading · IP Extraction | 2 |
| ip-keeper | IP Keeper | IP Registry · Zenodo | 2 |
| freya | Freya | Strategy · Opportunities | 3 |
| the-wolf | The Wolf | Legal · Contracts · Finance Strategy | 3 |
| frankie-master | Frankie Master | Narrative · Brand · Voice | 3 |
| frankie-content | Frankie Content | Content Production | 2 |
| frankie-branding | Frankie Branding | Visual Identity · Design | 2 |
| ventura-hep | Ventura Hep | Product · Experience | 2 |
| serena | Serena | AMI · House of Us | 2 |
| doctor-m | Doctor M | Academic Road · Publications | 2 |

---

### Constitutional versioning — the Canary

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

### Legal entities

- **OKKA Expanded Intelligence OÜ** — Estonia, reg. 17460303
- **RIECAT FAM / AMI (Awesome Minds Institute)** — Belgian ASBL, forming
- **OKKA AI Ventura** — internal division of OÜ

---

*OAK Protocol is built and maintained by OKKA Expanded Intelligence OÜ.*
*The organism deliberates. V seals. Interagat, ergo sit.*
