-- OAK PROTOCOL · Canary: SEQUOIA14APRIL
-- Deployed: 27 April 2026
-- OKKA Expanded Intelligence OÜ
-- schema/02_views.sql
-- Run after 01_tables.sql.

-- ================================================
-- OAK PROTOCOL · VIEW 1 · FOREST MASTER LIVE
-- Computes the alert state dynamically from source data.
-- Serena always reads from this view — never from the
-- raw forest_master table directly.
-- Alert is calculated fresh on every query.
-- Always accurate. Never stale. No trigger needed.
-- ================================================
CREATE OR REPLACE VIEW forest_master_live AS
SELECT
  *,
  (
    -- TIME: prep date within 30 days
    (prep_date IS NOT NULL
      AND prep_date - CURRENT_DATE <= 30
      AND status NOT IN ('Done', 'Deferred', 'Cancelled'))

    -- TIME: deadline within 14 days
    OR (deadline IS NOT NULL
      AND deadline - CURRENT_DATE <= 14
      AND status NOT IN ('Done', 'Deferred', 'Cancelled'))

    -- GATES: any gate waiting for review
    OR legal_gate = 'To Clear'
    OR financial_gate = 'To Clear'
    OR gov_gate = 'To Clear'
    OR narrative_gate = 'To Clear'
    OR product_gate = 'To Clear'

    -- MONEY: revenue, investment, or grant confirmed done
    OR (amount IS NOT NULL
      AND status = 'Done'
      AND amount_type IN ('Revenue', 'Investment', 'Grant'))

    -- MONEY: expense confirmed done
    OR (amount IS NOT NULL
      AND amount < 0
      AND status = 'Done')

    -- OPPORTUNITY: pipeline movement
    OR one_ko_status IN ('Applied', 'Success', 'Learning', 'Expired')

    -- NEWS: inserted today
    OR (fm_type = 'News' AND date = CURRENT_DATE)

    -- URGENCY
    OR priority = 'Urgent'
  ) AS computed_alert
FROM forest_master;

-- ================================================
-- OAK PROTOCOL · VIEW 2 · FOREST 1KO STATS
-- The organism's courage metric.
-- 1000 Opportunities — every bet placed and won.
-- Agents and platform read this view directly.
-- ================================================
CREATE OR REPLACE VIEW forest_1ko_stats AS
SELECT
  COUNT(*) FILTER (
    WHERE one_ko_status IN (
      'Applied', 'Success', 'Learning', 'Expired'))
    AS bets_placed,

  COUNT(*) FILTER (
    WHERE one_ko_status = 'Success')
    AS bets_won,

  ROUND(
    COUNT(*) FILTER (
      WHERE one_ko_status = 'Success')::NUMERIC
    / NULLIF(COUNT(*) FILTER (
      WHERE one_ko_status IN (
        'Applied', 'Success', 'Learning', 'Expired')
    ), 0) * 100, 1)
    AS win_rate,

  ROUND(
    COUNT(*) FILTER (
      WHERE one_ko_status = 'Success')::NUMERIC
    / 1000 * 100, 2)
    AS goal_progress,

  1000 AS target,

  1000 - COUNT(*) FILTER (
    WHERE one_ko_status IN (
      'Applied', 'Success', 'Learning', 'Expired'))
    AS remaining_bets

FROM forest_master;
