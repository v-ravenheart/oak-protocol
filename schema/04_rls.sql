-- OAK PROTOCOL · Canary: SEQUOIA14APRIL
-- Deployed: 27 April 2026
-- OKKA Expanded Intelligence OÜ
-- RLS: authenticated = full access · anon = blocked · sealed Library docs = immutable

ALTER TABLE forest_master             ENABLE ROW LEVEL SECURITY;
ALTER TABLE forest_library            ENABLE ROW LEVEL SECURITY;
ALTER TABLE forest_library_change_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE seat_id                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE energy                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE maestro_vocabulary        ENABLE ROW LEVEL SECURITY;
ALTER TABLE canary                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE forest_now                ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fm_auth_full_access"     ON forest_master FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "fm_anon_blocked"         ON forest_master FOR ALL TO anon USING (FALSE);

-- forest_library: sealed documents cannot be updated (immutability enforced at DB level)
CREATE POLICY "fl_auth_read"            ON forest_library FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "fl_auth_insert"          ON forest_library FOR INSERT TO authenticated WITH CHECK (TRUE);
CREATE POLICY "fl_auth_update_unsealed" ON forest_library FOR UPDATE TO authenticated USING (sealed = FALSE) WITH CHECK (TRUE);
CREATE POLICY "fl_anon_blocked"         ON forest_library FOR ALL TO anon USING (FALSE);

CREATE POLICY "changelog_auth_read"    ON forest_library_change_log FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "changelog_auth_insert"  ON forest_library_change_log FOR INSERT TO authenticated WITH CHECK (TRUE);
CREATE POLICY "changelog_anon_blocked" ON forest_library_change_log FOR ALL TO anon USING (FALSE);

CREATE POLICY "alerts_auth_full_access" ON alerts FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "alerts_anon_blocked"     ON alerts FOR ALL TO anon USING (FALSE);

CREATE POLICY "seat_auth_read"    ON seat_id FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "seat_anon_blocked" ON seat_id FOR ALL TO anon USING (FALSE);

CREATE POLICY "energy_auth_read"    ON energy FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "energy_anon_blocked" ON energy FOR ALL TO anon USING (FALSE);

CREATE POLICY "vocab_auth_read"    ON maestro_vocabulary FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "vocab_anon_blocked" ON maestro_vocabulary FOR ALL TO anon USING (FALSE);

CREATE POLICY "canary_auth_read"    ON canary FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "canary_anon_blocked" ON canary FOR ALL TO anon USING (FALSE);

CREATE POLICY "fn_auth_full_access" ON forest_now FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);
CREATE POLICY "fn_anon_blocked"     ON forest_now FOR ALL TO anon USING (FALSE);
