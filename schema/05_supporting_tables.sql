-- OAK PROTOCOL · Canary: SEQUOIA14APRIL
-- Deployed: 27 April 2026
-- OKKA Expanded Intelligence OÜ
-- Supporting tables 2, 3, 5, 6, 7, 9
-- (seat_id = Table 8, energy = Table 4, maestro_vocabulary = Table 5 — in 01_tables.sql)

-- ================================================
-- FACT SHEET · Table 2 · Keeper: The Bard · Sealer: V
-- ================================================
CREATE TABLE IF NOT EXISTS fact_sheet (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  category         TEXT NOT NULL,
  fact_label       TEXT NOT NULL,
  fact_value       TEXT,
  last_updated     TIMESTAMPTZ DEFAULT NOW(),
  updated_by       TEXT,
  source_fm_link   UUID REFERENCES forest_master(id) ON DELETE SET NULL,
  source_lib_link  UUID REFERENCES forest_library(id) ON DELETE SET NULL,
  goes_stale       BOOLEAN DEFAULT FALSE,
  review_frequency TEXT,
  canary           TEXT DEFAULT 'SEQUOIA14APRIL',
  inserted_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_fact_category ON fact_sheet(category);

ALTER TABLE fact_sheet ENABLE ROW LEVEL SECURITY;
CREATE POLICY "fact_auth_full"    ON fact_sheet FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "fact_anon_blocked" ON fact_sheet FOR ALL TO anon USING (FALSE);

-- ================================================
-- ENTITY REGISTRY · Table 3 · Keeper: All seats · Sealer: V
-- ================================================
CREATE TABLE IF NOT EXISTS entity_registry (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  entity_ref          TEXT UNIQUE,
  entity_name         TEXT NOT NULL,
  entity_type         TEXT[],
  relationship_status TEXT CHECK (relationship_status IN (
                        'Prospect','Active','Past','Blocked')),
  jurisdiction        TEXT,
  registration_number TEXT,
  address             TEXT,
  key_contact         TEXT,
  contact_email       TEXT,
  contact_linkedin    TEXT,
  notes               TEXT,
  legal_register_link UUID REFERENCES forest_library(id) ON DELETE SET NULL,
  fm_row_link         UUID REFERENCES forest_master(id) ON DELETE SET NULL,
  canary              TEXT DEFAULT 'SEQUOIA14APRIL',
  inserted_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_entity_type   ON entity_registry USING GIN(entity_type);
CREATE INDEX idx_entity_status ON entity_registry(relationship_status);

ALTER TABLE entity_registry ENABLE ROW LEVEL SECURITY;
CREATE POLICY "entity_auth_full"    ON entity_registry FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "entity_anon_blocked" ON entity_registry FOR ALL TO anon USING (FALSE);

-- ================================================
-- IP ASSETS AND KNOWLEDGE · Table 5 · Keeper: Doctor M + Frankie Master
-- ================================================
CREATE TABLE IF NOT EXISTS ip_assets_knowledge (
  id                 UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title              TEXT NOT NULL,
  ip_type            TEXT CHECK (ip_type IN (
                       'Book','Paper','Framework','Research Programme',
                       'Dataset','Brand Asset','Methodology','Other')),
  series             TEXT,
  research_area      TEXT,
  doi                TEXT,
  orcid_linked       BOOLEAN DEFAULT FALSE,
  date_produced      DATE,
  keeper             TEXT REFERENCES seat_id(seat_slug) ON UPDATE CASCADE,
  application_target TEXT,
  application_status TEXT,
  requirements_met   BOOLEAN DEFAULT FALSE,
  deadline           DATE,
  result             TEXT,
  fm_row_link        UUID REFERENCES forest_master(id) ON DELETE SET NULL,
  lib_row_link       UUID REFERENCES forest_library(id) ON DELETE SET NULL,
  canary             TEXT DEFAULT 'SEQUOIA14APRIL',
  inserted_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE ip_assets_knowledge ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ip_auth_full"    ON ip_assets_knowledge FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "ip_anon_blocked" ON ip_assets_knowledge FOR ALL TO anon USING (FALSE);

-- ================================================
-- LEGAL TABLE · Table 6 · Keeper: The Wolf · Sealer: Wolf proposes, V seals
-- Three sections: Jurisdictions, Contract Status, Legal Records
-- ================================================
CREATE TABLE IF NOT EXISTS legal_table (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  legal_ref        TEXT UNIQUE,
  section          TEXT CHECK (section IN (
                     'Jurisdiction','Contract Status','Legal Record')),
  name             TEXT NOT NULL,
  definition       TEXT,
  counterparty_ref TEXT REFERENCES entity_registry(entity_ref) ON UPDATE CASCADE,
  contract_status  TEXT,
  signed_date      DATE,
  expiry_date      DATE,
  fm_row_link      UUID REFERENCES forest_master(id) ON DELETE SET NULL,
  lib_row_link     UUID REFERENCES forest_library(id) ON DELETE SET NULL,
  canary           TEXT DEFAULT 'SEQUOIA14APRIL',
  inserted_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_legal_section ON legal_table(section);

ALTER TABLE legal_table ENABLE ROW LEVEL SECURITY;
CREATE POLICY "legal_auth_full"    ON legal_table FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "legal_anon_blocked" ON legal_table FOR ALL TO anon USING (FALSE);

-- ================================================
-- FINANCE · Table 7 · Keeper: Freya + Wolf + Mercury
-- ================================================
CREATE TABLE IF NOT EXISTS finance (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  finance_type  TEXT CHECK (finance_type IN (
                  'Revenue Target','Pipeline Entry','Grant Prospect',
                  'OpEx','Tool Subscription','Token Cost',
                  'Revenue Milestone','Shareholder Loan',
                  'Pricing Strategy','Financial Strategy')),
  title         TEXT NOT NULL,
  entity_ref    TEXT REFERENCES entity_registry(entity_ref) ON UPDATE CASCADE,
  amount        NUMERIC,
  currency      TEXT DEFAULT 'EUR',
  probability   NUMERIC CHECK (probability >= 0 AND probability <= 100),
  expected_date DATE,
  actual_date   DATE,
  status        TEXT,
  grant_funded  BOOLEAN DEFAULT FALSE,
  recurring     BOOLEAN DEFAULT FALSE,
  frequency     TEXT,
  notes         TEXT,
  fm_row_link   UUID REFERENCES forest_master(id) ON DELETE SET NULL,
  keeper        TEXT REFERENCES seat_id(seat_slug) ON UPDATE CASCADE,
  v_sealed      BOOLEAN DEFAULT FALSE,
  canary        TEXT DEFAULT 'SEQUOIA14APRIL',
  inserted_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_finance_type   ON finance(finance_type);
CREATE INDEX idx_finance_status ON finance(status);

ALTER TABLE finance ENABLE ROW LEVEL SECURITY;
CREATE POLICY "finance_auth_full"    ON finance FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "finance_anon_blocked" ON finance FOR ALL TO anon USING (FALSE);

-- ================================================
-- CONTENT PIPELINE · Table 9 · Keeper: Frankie Master · Sealer: Frankie proposes, V seals
-- ================================================
CREATE TABLE IF NOT EXISTS content_pipeline (
  id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  scheduled_date DATE,
  title          TEXT NOT NULL,
  content_type   TEXT CHECK (content_type IN (
                   'Book Content','Reflection','Provocation',
                   'Ugly Ship Friday','Behind the Scenes','Other')),
  series         TEXT,
  status         TEXT CHECK (status IN (
                   'To Do','Drafting','Ready','Posted','Archived'))
                 DEFAULT 'To Do',
  platform       TEXT,
  fm_row_link    UUID REFERENCES forest_master(id) ON DELETE SET NULL,
  lib_row_link   UUID REFERENCES forest_library(id) ON DELETE SET NULL,
  author         TEXT REFERENCES seat_id(seat_slug) ON UPDATE CASCADE,
  energy_period  TEXT,
  v_sealed       BOOLEAN DEFAULT FALSE,
  canary         TEXT DEFAULT 'SEQUOIA14APRIL',
  inserted_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_content_date   ON content_pipeline(scheduled_date);
CREATE INDEX idx_content_status ON content_pipeline(status);

ALTER TABLE content_pipeline ENABLE ROW LEVEL SECURITY;
CREATE POLICY "content_auth_full"    ON content_pipeline FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "content_anon_blocked" ON content_pipeline FOR ALL TO anon USING (FALSE);
