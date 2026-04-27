-- OAK PROTOCOL · Canary: SEQUOIA14APRIL
-- Deployed: 27 April 2026
-- OKKA Expanded Intelligence OÜ

-- ================================================
-- TABLE 1 · CANARY · Constitutional version tracking
-- ================================================
CREATE TABLE IF NOT EXISTS canary (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  canary_code     TEXT NOT NULL,
  canary_type     TEXT NOT NULL DEFAULT 'tree',
  date            DATE NOT NULL DEFAULT CURRENT_DATE,
  what_changed    TEXT,
  sealed_by       TEXT NOT NULL DEFAULT 'V',
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO canary (canary_code, canary_type, date, what_changed, sealed_by) VALUES (
  'SEQUOIA14APRIL', 'tree', '2026-04-14',
  'Forest Library architecture and roundtable sessions 01-02 complete. Full data architecture sealed.',
  'V Ravenheart'
);

-- ================================================
-- TABLE 2 · FOREST NOW · Live organism snapshot. Always one row.
-- snapshot_date: renamed from current_date (Postgres reserved keyword)
-- ================================================
CREATE TABLE IF NOT EXISTS forest_now (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  snapshot_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  canary          TEXT NOT NULL DEFAULT 'SEQUOIA14APRIL',
  energy_period   TEXT,
  day_focus       TEXT,
  next_deadline   TEXT,
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO forest_now (canary) VALUES ('SEQUOIA14APRIL');

-- ================================================
-- TABLE 3 · SEAT ID · Identity record for all seats
-- ================================================
CREATE TABLE IF NOT EXISTS seat_id (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  seat_number      TEXT,
  seat_name        TEXT NOT NULL,
  seat_slug        TEXT NOT NULL UNIQUE,
  seat_emoji       TEXT,
  trust_tier       INTEGER NOT NULL DEFAULT 2 CHECK (trust_tier IN (1, 2, 3)),
  domain           TEXT,
  function_desc    TEXT,
  system_prompt    TEXT,
  rules_of_eng     TEXT,
  founding_canary  TEXT DEFAULT 'SEQUOIA14APRIL',
  chronicle_slug   TEXT,
  working_doc_slug TEXT,
  active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================
-- TABLE 4 · ENERGY · Operational calendar. Mercury keeper. Read only.
-- 15 columns including period_phase (moved from Forest Master per RT-002)
-- ================================================
CREATE TABLE IF NOT EXISTS energy (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  month            TEXT,
  date             DATE NOT NULL UNIQUE,
  weekday          TEXT,
  weekly_flow      TEXT,
  energy_milestone TEXT,
  energy_period    TEXT,
  astrological_evt TEXT,
  op_direction     TEXT,
  moon_in_sign     TEXT,
  phase_and_energy TEXT,
  voc              TEXT,
  tone_of_day      TEXT,
  period_tracking  BOOLEAN DEFAULT FALSE,
  period_phase     TEXT,
  milestone        BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_energy_date ON energy(date);

-- ================================================
-- TABLE 5 · MAESTRO VOCABULARY · Dropdown values for FM and Library
-- ================================================
CREATE TABLE IF NOT EXISTS maestro_vocabulary (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  vocab_type     TEXT NOT NULL,
  name           TEXT NOT NULL,
  definition     TEXT,
  drive_folder   TEXT,
  template_id    TEXT,
  display_order  INTEGER,
  active         BOOLEAN DEFAULT TRUE,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(vocab_type, name)
);

-- ================================================
-- TABLE 6 · FOREST MASTER · The action register.
-- 44 user-visible columns (V spec) + id + canary + inserted_at = 47 total.
-- Column order is authoritative — matches V's confirmed Google Sheet sequence.
-- ================================================
CREATE TABLE IF NOT EXISTS forest_master (
  id                    UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- V's 44 columns in confirmed sequence
  alert                 BOOLEAN DEFAULT FALSE,
  inserted_by           TEXT,
  title                 TEXT NOT NULL,
  entity                TEXT,
  type                  TEXT,
  date                  DATE DEFAULT CURRENT_DATE,
  deadline              DATE,
  description           TEXT,
  action_needed         TEXT,
  status                TEXT CHECK (status IN (
                          'To Do','Agent Draft','Agent Action',
                          'Review','Doing','Done','Deferred','Cancelled')),
  priority              TEXT CHECK (priority IN (
                          'Urgent','Important','Regular','Low','Nice to have')),
  opportunity_status    TEXT CHECK (opportunity_status IN (
                          'To Do','Auto Apply','Review',
                          'Applied','Success','Learning','Expired')),
  energy_period         TEXT,
  day_focus             TEXT,
  calendar              TEXT,
  oak_part              TEXT CHECK (oak_part IN (
                          'Roots','Trunk','Branch','All Forest')),
  area                  TEXT,
  research_areas        TEXT[],
  ip_doi_asset          TEXT[],
  amount                NUMERIC,
  amount_type           TEXT,
  prep_date             DATE,
  return_date           DATE,
  keeper                TEXT REFERENCES seat_id(seat_slug) ON UPDATE CASCADE,
  col_25_reserved       TEXT,
  related_seats         TEXT[],
  forest_library_link   TEXT,
  connects_to_table     TEXT,
  mag_area_title        TEXT,
  action                BOOLEAN DEFAULT FALSE,
  forest_roadmap        BOOLEAN DEFAULT FALSE,
  hs_collaboration      BOOLEAN DEFAULT FALSE,
  product_gate          TEXT DEFAULT 'N/A' CHECK (product_gate IN ('N/A','To Clear','Cleared')),
  goes_to_fact_sheet    BOOLEAN DEFAULT FALSE,
  legal_gate            TEXT DEFAULT 'N/A' CHECK (legal_gate IN ('N/A','To Clear','Cleared')),
  financial_gate        TEXT DEFAULT 'N/A' CHECK (financial_gate IN ('N/A','To Clear','Cleared')),
  gov_gate              TEXT DEFAULT 'N/A' CHECK (gov_gate IN ('N/A','To Clear','Cleared')),
  agentic_governance    BOOLEAN DEFAULT FALSE,
  narrative_gate        TEXT DEFAULT 'N/A' CHECK (narrative_gate IN ('N/A','To Clear','Cleared')),
  doi_gate              TEXT CHECK (doi_gate IN (
                          'Not Applicable','Flagged','Agent Draft','Review',
                          'Submitted','Live','ORCID Linked','Cited')),
  forest_library_status TEXT DEFAULT 'To Do' CHECK (forest_library_status IN (
                          'To Do','To Create','Agent Draft',
                          'Created','Reviewed','V Sealed')),
  connects_to           TEXT[],
  last_updated          TIMESTAMPTZ DEFAULT NOW(),
  system_created        BOOLEAN NOT NULL DEFAULT FALSE,

  -- System columns
  canary                TEXT DEFAULT 'SEQUOIA14APRIL',
  inserted_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_fm_status   ON forest_master(status);
CREATE INDEX idx_fm_type     ON forest_master(type);
CREATE INDEX idx_fm_deadline ON forest_master(deadline);
CREATE INDEX idx_fm_keeper   ON forest_master(keeper);
CREATE INDEX idx_fm_opp      ON forest_master(opportunity_status);
CREATE INDEX idx_fm_inserted ON forest_master(inserted_at DESC);
CREATE INDEX idx_fm_alert    ON forest_master(alert) WHERE alert = TRUE;
CREATE INDEX idx_fm_roadmap  ON forest_master(forest_roadmap) WHERE forest_roadmap = TRUE;

-- ================================================
-- TABLE 7 · FOREST LIBRARY · The memory layer.
-- Every document the organism writes. One row per document.
-- Immutable after sealing (enforced by RLS in 04_rls.sql).
-- ================================================
CREATE TABLE IF NOT EXISTS forest_library (
  id                UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  collections       TEXT[],
  books             TEXT[],
  related_branch    TEXT[],
  document_type     TEXT,
  document_title    TEXT NOT NULL,
  author            TEXT[],
  co_author         TEXT[],
  sealing_seat      TEXT,
  date              DATE DEFAULT CURRENT_DATE,
  canary            TEXT DEFAULT 'SEQUOIA14APRIL',
  executive_summary TEXT,
  first_200_words   TEXT,
  full_document     TEXT NOT NULL,
  drive_folder      TEXT,
  drive_link        TEXT,
  reference_number  TEXT,
  status            TEXT NOT NULL DEFAULT 'Created' CHECK (status IN (
                      'To Create','Agent Draft','Created','Reviewed','V Sealed')),
  fm_status         TEXT DEFAULT 'To Create',
  fm_row_link       UUID,
  append_on         BOOLEAN NOT NULL DEFAULT FALSE,
  sealed            BOOLEAN NOT NULL DEFAULT FALSE,
  mag_append        BOOLEAN DEFAULT FALSE,
  alert             BOOLEAN DEFAULT FALSE,
  goes_to_factsheet BOOLEAN DEFAULT FALSE,
  collaboration     BOOLEAN DEFAULT FALSE,
  row_type          TEXT NOT NULL CHECK (row_type IN (
                      'First Page','Chronicle','Legal Record','SoC',
                      'Publication Record','Roundtable',
                      'Roundtable Verse','Working Document')),
  entry_id          TEXT,
  verse_for_seat    TEXT,
  support_table_lnk TEXT,
  first_page_link   UUID,
  soc_changed       BOOLEAN,
  soc_change_record TEXT,
  doi               TEXT,
  orcid_linked      BOOLEAN DEFAULT FALSE,
  legal_gate_fm_id  UUID,
  system_created    BOOLEAN NOT NULL DEFAULT FALSE,
  inserted_by       TEXT,
  inserted_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_fl_status   ON forest_library(status);
CREATE INDEX idx_fl_sealed   ON forest_library(sealed);
CREATE INDEX idx_fl_row_type ON forest_library(row_type);
CREATE INDEX idx_fl_inserted ON forest_library(inserted_at DESC);
CREATE INDEX idx_fl_fm_link  ON forest_library(fm_row_link);

-- ================================================
-- TABLE 8 · FOREST LIBRARY CHANGE LOG · Append-only audit trail
-- ================================================
CREATE TABLE IF NOT EXISTS forest_library_change_log (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  library_row_id  UUID NOT NULL REFERENCES forest_library(id) ON DELETE RESTRICT,
  event_type      TEXT NOT NULL CHECK (event_type IN (
                    'Created','Appended','Sealed','Updated',
                    'ORCID Linked','Drive Linked','Archived')),
  author          TEXT,
  author_is_v     BOOLEAN DEFAULT FALSE,
  event_date      TIMESTAMPTZ DEFAULT NOW(),
  canary          TEXT DEFAULT 'SEQUOIA14APRIL',
  content_added   TEXT,
  change_summary  TEXT,
  previous_value  TEXT,
  new_value       TEXT,
  triggered_by_fm UUID
);

CREATE INDEX idx_changelog_lib ON forest_library_change_log(library_row_id);

-- ================================================
-- TABLE 9 · ALERTS · Event log. Requires explicit acknowledgment.
-- ================================================
CREATE TABLE IF NOT EXISTS alerts (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  fm_row_link     UUID REFERENCES forest_master(id) ON DELETE SET NULL,
  lib_row_link    UUID REFERENCES forest_library(id) ON DELETE SET NULL,
  event_type      TEXT NOT NULL,
  event_desc      TEXT,
  seat_target     TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  acknowledged    BOOLEAN DEFAULT FALSE,
  acknowledged_by TEXT,
  acknowledged_at TIMESTAMPTZ
);

CREATE INDEX idx_alerts_unacked ON alerts(acknowledged) WHERE acknowledged = FALSE;
CREATE INDEX idx_alerts_fm      ON alerts(fm_row_link);
