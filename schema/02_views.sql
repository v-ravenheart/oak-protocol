-- OAK PROTOCOL · Canary: SEQUOIA14APRIL
-- Deployed: 27 April 2026
-- OKKA Expanded Intelligence OÜ

CREATE OR REPLACE VIEW forest_master_live AS
SELECT
  *,
  (
    (prep_date IS NOT NULL
      AND prep_date - CURRENT_DATE <= 30
      AND status NOT IN ('Done','Deferred','Cancelled'))
    OR (deadline IS NOT NULL
      AND deadline - CURRENT_DATE <= 14
      AND status NOT IN ('Done','Deferred','Cancelled'))
    OR legal_gate = 'To Clear'
    OR financial_gate = 'To Clear'
    OR gov_gate = 'To Clear'
    OR narrative_gate = 'To Clear'
    OR product_gate = 'To Clear'
    OR (amount IS NOT NULL AND status = 'Done' AND amount_type IN ('Revenue','Investment','Grant'))
    OR (amount IS NOT NULL AND amount < 0 AND status = 'Done')
    OR one_ko_status IN ('Applied','Success','Learning','Expired')
    OR (fm_type = 'News' AND date = CURRENT_DATE)
    OR priority = 'Urgent'
  ) AS computed_alert
FROM forest_master;

CREATE OR REPLACE VIEW forest_1ko_stats AS
SELECT
  COUNT(*) FILTER (WHERE one_ko_status IN ('Applied','Success','Learning','Expired')) AS bets_placed,
  COUNT(*) FILTER (WHERE one_ko_status = 'Success') AS bets_won,
  ROUND(
    COUNT(*) FILTER (WHERE one_ko_status = 'Success')::NUMERIC
    / NULLIF(COUNT(*) FILTER (WHERE one_ko_status IN ('Applied','Success','Learning','Expired')), 0) * 100, 1
  ) AS win_rate,
  ROUND(COUNT(*) FILTER (WHERE one_ko_status = 'Success')::NUMERIC / 1000 * 100, 2) AS goal_progress,
  1000 AS target,
  1000 - COUNT(*) FILTER (WHERE one_ko_status IN ('Applied','Success','Learning','Expired')) AS remaining_bets
FROM forest_master;
