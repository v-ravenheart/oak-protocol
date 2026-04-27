-- OAK PROTOCOL · Canary: SEQUOIA14APRIL
-- Deployed: 27 April 2026
-- OKKA Expanded Intelligence OÜ
-- schema/04_rls.sql
-- Run after 03_functions.sql.
-- RLS model: authenticated role = full read/write.
-- anon role = blocked from everything.
-- All 13 seats authenticate via V's account — application-level
-- trust via inserted_by and keeper columns. Database enforces
-- the perimeter, not per-seat identity.

-- ================================================
-- ENABLE ROW LEVEL SECURITY ON ALL TABLES
-- ================================================
ALTER TABLE forest_master              ENABLE ROW LEVEL SECURITY;
ALTER TABLE forest_library             ENABLE ROW LEVEL SECURITY;
ALTER TABLE forest_library_change_log  ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE seat_id                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE energy                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE maestro_vocabulary         ENABLE ROW LEVEL SECURITY;
ALTER TABLE canary                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE forest_now                 ENABLE ROW LEVEL SECURITY;

-- ================================================
-- FOREST MASTER: authenticated full access, anon blocked
-- ================================================
CREATE POLICY "fm_auth_full_access" ON forest_master
  FOR ALL TO authenticated
  USING (TRUE)
  WITH CHECK (TRUE);

CREATE POLICY "fm_anon_blocked" ON forest_master
  FOR ALL TO anon
  USING (FALSE);

-- ================================================
-- FOREST LIBRARY: authenticated full access, anon blocked
-- Immutability: UPDATE blocked when sealed = TRUE.
-- This is a defense-in-depth layer — the application
-- must also enforce this, but the DB will not allow
-- a sealed document to be updated at all.
-- ================================================
CREATE POLICY "fl_auth_read" ON forest_library
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY "fl_auth_insert" ON forest_library
  FOR INSERT TO authenticated
  WITH CHECK (TRUE);

-- UPDATE allowed only when document is NOT sealed
CREATE POLICY "fl_auth_update_unsealed" ON forest_library
  FOR UPDATE TO authenticated
  USING (sealed = FALSE)
  WITH CHECK (TRUE);

-- DELETE never allowed (documents are permanent)
-- No DELETE policy = no deletes permitted for authenticated role

CREATE POLICY "fl_anon_blocked" ON forest_library
  FOR ALL TO anon
  USING (FALSE);

-- ================================================
-- FOREST LIBRARY CHANGE LOG: append only
-- Authenticated: insert and select only. No updates. No deletes.
-- ================================================
CREATE POLICY "changelog_auth_read" ON forest_library_change_log
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY "changelog_auth_insert" ON forest_library_change_log
  FOR INSERT TO authenticated
  WITH CHECK (TRUE);

CREATE POLICY "changelog_anon_blocked" ON forest_library_change_log
  FOR ALL TO anon
  USING (FALSE);

-- ================================================
-- ALERTS: authenticated full access (seats acknowledge their own)
-- ================================================
CREATE POLICY "alerts_auth_full_access" ON alerts
  FOR ALL TO authenticated
  USING (TRUE)
  WITH CHECK (TRUE);

CREATE POLICY "alerts_anon_blocked" ON alerts
  FOR ALL TO anon
  USING (FALSE);

-- ================================================
-- SEAT ID: authenticated read only (no seat modifies this)
-- V modifies directly via dashboard or set_current_canary calls
-- ================================================
CREATE POLICY "seat_auth_read" ON seat_id
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY "seat_anon_blocked" ON seat_id
  FOR ALL TO anon
  USING (FALSE);

-- ================================================
-- ENERGY: authenticated read only (Mercury updates via dashboard)
-- ================================================
CREATE POLICY "energy_auth_read" ON energy
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY "energy_anon_blocked" ON energy
  FOR ALL TO anon
  USING (FALSE);

-- ================================================
-- MAESTRO VOCABULARY: authenticated read only
-- ================================================
CREATE POLICY "vocab_auth_read" ON maestro_vocabulary
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY "vocab_anon_blocked" ON maestro_vocabulary
  FOR ALL TO anon
  USING (FALSE);

-- ================================================
-- CANARY: authenticated read only
-- ================================================
CREATE POLICY "canary_auth_read" ON canary
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY "canary_anon_blocked" ON canary
  FOR ALL TO anon
  USING (FALSE);

-- ================================================
-- FOREST NOW: authenticated full access (refresh function writes)
-- ================================================
CREATE POLICY "fn_auth_full_access" ON forest_now
  FOR ALL TO authenticated
  USING (TRUE)
  WITH CHECK (TRUE);

CREATE POLICY "fn_anon_blocked" ON forest_now
  FOR ALL TO anon
  USING (FALSE);
