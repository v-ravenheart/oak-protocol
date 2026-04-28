-- OAK PROTOCOL · Dashboard Layer
-- Canary: SEQUOIA14APRIL · Built: RT-002 session, 27-28 April 2026
-- OKKA Expanded Intelligence OÜ
--
-- Applies: Il Maestro dashboard brief (28 April 2026)
-- Migrations 11-16 in Serena Supabase (bpxgeaycrfsxqoqfakqj)
--
-- Sections:
--   1. Column additions (forest_master, entity_registry, content_pipeline)
--   2. forest_1ko_stats view rebuild
--   3. get_content_metrics() function
--   4. forest_snapshot view
--   5. get_dashboard() unified function


-- ================================================
-- SECTION 1 · COLUMN ADDITIONS
-- ================================================

-- forest_master: signals, celebration flag, key_learning
ALTER TABLE forest_master
  ADD COLUMN IF NOT EXISTS signals_category TEXT CHECK (signals_category IN (
    'Market Signal','Regulatory','Technology','Competitor',
    'Partnership','Community','Personal','Other')),
  ADD COLUMN IF NOT EXISTS celebration BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS key_learning TEXT;

-- entity_registry: relationship intelligence
ALTER TABLE entity_registry
  ADD COLUMN IF NOT EXISTS last_contact_date DATE,
  ADD COLUMN IF NOT EXISTS is_strategic BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS relationship_health TEXT CHECK (relationship_health IN (
    'Active','Needs Attention','At Risk','Dormant'));

-- content_pipeline: publishing tracking + expanded status
ALTER TABLE content_pipeline
  ADD COLUMN IF NOT EXISTS published_date DATE,
  ADD COLUMN IF NOT EXISTS post_url TEXT,
  ADD COLUMN IF NOT EXISTS published BOOLEAN DEFAULT FALSE;

ALTER TABLE content_pipeline
  DROP CONSTRAINT IF EXISTS content_pipeline_status_check;
ALTER TABLE content_pipeline
  ADD CONSTRAINT content_pipeline_status_check
  CHECK (status IN (
    'To Do','Drafting','Ready','Ready to Review',
    'Approved','Posted','Archived','Cancelled'));


-- ================================================
-- SECTION 2 · forest_1ko_stats VIEW REBUILD
-- Courage meter and opportunity pipeline metrics.
-- ================================================
DROP VIEW IF EXISTS forest_1ko_stats;

CREATE VIEW forest_1ko_stats AS
SELECT
  -- Opportunity counts
  COUNT(*) FILTER (WHERE opportunity_status IS NOT NULL
    AND opportunity_status != 'To Do')                      AS total_bets,
  COUNT(*) FILTER (WHERE opportunity_status = 'To Do')      AS to_do,
  COUNT(*) FILTER (WHERE opportunity_status = 'Auto Apply') AS auto_apply,
  COUNT(*) FILTER (WHERE opportunity_status = 'Review')     AS in_review,
  COUNT(*) FILTER (WHERE opportunity_status = 'Applied')    AS applied,
  COUNT(*) FILTER (WHERE opportunity_status = 'Success')    AS won,
  COUNT(*) FILTER (WHERE opportunity_status = 'Learning')   AS learning,
  COUNT(*) FILTER (WHERE opportunity_status = 'Expired')    AS expired,

  -- Courage meter: bets placed / target (1000)
  1000                                                       AS target,
  1000 - COUNT(*) FILTER (WHERE opportunity_status IS NOT NULL
    AND opportunity_status != 'To Do')                      AS remaining_bets,

  ROUND(
    COUNT(*) FILTER (WHERE opportunity_status IS NOT NULL
      AND opportunity_status != 'To Do')::NUMERIC / 1000, 4
  )                                                          AS courage_meter,

  -- Win rate and learning rate (null when no bets placed yet)
  CASE
    WHEN COUNT(*) FILTER (WHERE opportunity_status IN (
           'Applied','Success','Learning','Expired')) > 0
    THEN ROUND(
      COUNT(*) FILTER (WHERE opportunity_status = 'Success')::NUMERIC /
      COUNT(*) FILTER (WHERE opportunity_status IN (
        'Applied','Success','Learning','Expired')), 4)
    ELSE NULL
  END                                                        AS win_rate,

  CASE
    WHEN COUNT(*) FILTER (WHERE opportunity_status IN (
           'Success','Learning','Expired')) > 0
    THEN ROUND(
      COUNT(*) FILTER (WHERE opportunity_status = 'Learning')::NUMERIC /
      COUNT(*) FILTER (WHERE opportunity_status IN (
        'Success','Learning','Expired')), 4)
    ELSE NULL
  END                                                        AS learning_rate,

  -- Average days from date to deadline for won bets
  COALESCE(
    ROUND(AVG(
      CASE WHEN opportunity_status = 'Success' AND deadline IS NOT NULL AND date IS NOT NULL
           THEN (deadline - date)::NUMERIC END
    ), 1), 0
  )                                                          AS avg_days_to_win,

  -- Pipeline value (applied bets with amounts)
  COALESCE(
    SUM(amount) FILTER (WHERE opportunity_status = 'Applied'), 0
  )                                                          AS pipeline_value,

  COALESCE(
    SUM(amount) FILTER (WHERE opportunity_status = 'Success'), 0
  )                                                          AS total_won_value

FROM forest_master
WHERE system_created = FALSE;


-- ================================================
-- SECTION 3 · get_content_metrics() FUNCTION
-- ================================================
CREATE OR REPLACE FUNCTION get_content_metrics()
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_platforms      TEXT[] := ARRAY['LinkedIn','Substack','TikTok','Instagram'];
  v_platform_stats JSONB;
  v_pipeline       JSONB;
  v_heatmap        JSONB;
BEGIN
  -- Per-platform stats
  -- Note: DATE - DATE returns INTEGER in Postgres (not interval), use direct cast
  SELECT jsonb_object_agg(
    p.platform,
    jsonb_build_object(
      'last_published', (
        SELECT MAX(published_date) FROM content_pipeline
        WHERE platform = p.platform AND published = TRUE),
      'posts_this_month', (
        SELECT COUNT(*) FROM content_pipeline
        WHERE platform = p.platform AND published = TRUE
        AND date_trunc('month', published_date) = date_trunc('month', CURRENT_DATE)),
      'posts_this_year', (
        SELECT COUNT(*) FROM content_pipeline
        WHERE platform = p.platform AND published = TRUE
        AND EXTRACT(year FROM published_date) = EXTRACT(year FROM CURRENT_DATE)),
      'days_since_last_post', (
        SELECT COALESCE(
          (CURRENT_DATE - MAX(published_date))::INTEGER, 999)
        FROM content_pipeline
        WHERE platform = p.platform AND published = TRUE),
      'is_overdue', (
        COALESCE(
          (CURRENT_DATE - (
            SELECT MAX(published_date) FROM content_pipeline
            WHERE platform = p.platform AND published = TRUE
          )) > 7,
          TRUE))
    )
  ) INTO v_platform_stats
  FROM unnest(v_platforms) AS p(platform);

  -- Pipeline by status
  SELECT jsonb_build_object(
    'to_do',           COUNT(*) FILTER (WHERE status = 'To Do'),
    'drafting',        COUNT(*) FILTER (WHERE status = 'Drafting'),
    'ready_to_review', COUNT(*) FILTER (WHERE status = 'Ready to Review'),
    'approved',        COUNT(*) FILTER (WHERE status = 'Approved'),
    'scheduled',       COUNT(*) FILTER (
                         WHERE status = 'Approved' AND scheduled_date >= CURRENT_DATE),
    'total_pipeline',  COUNT(*) FILTER (
                         WHERE status NOT IN ('Posted','Cancelled','Archived'))
  ) INTO v_pipeline
  FROM content_pipeline;

  -- Last 30 days heatmap
  SELECT jsonb_agg(
    jsonb_build_object(
      'date',      day_date,
      'count',     post_count,
      'platforms', platforms_posted
    ) ORDER BY day_date
  ) INTO v_heatmap
  FROM (
    SELECT
      published_date               AS day_date,
      COUNT(*)                     AS post_count,
      array_agg(DISTINCT platform) AS platforms_posted
    FROM content_pipeline
    WHERE published = TRUE
    AND published_date >= CURRENT_DATE - 30
    GROUP BY published_date
  ) heatmap_data;

  RETURN jsonb_build_object(
    'platforms',                v_platform_stats,
    'pipeline',                 v_pipeline,
    'heatmap_last_30_days',     COALESCE(v_heatmap, '[]'::jsonb),
    'total_published_all_time', (
      SELECT COUNT(*) FROM content_pipeline WHERE published = TRUE),
    'next_scheduled', (
      SELECT jsonb_build_object(
        'title', title, 'platform', platform, 'date', scheduled_date)
      FROM content_pipeline
      WHERE scheduled_date >= CURRENT_DATE
      AND status NOT IN ('Posted','Cancelled','Archived')
      ORDER BY scheduled_date ASC LIMIT 1)
  );
END;
$$;


-- ================================================
-- SECTION 4 · forest_snapshot VIEW
-- Single-row organism health summary.
-- ================================================
DROP VIEW IF EXISTS forest_snapshot;

CREATE VIEW forest_snapshot AS
SELECT
  -- Volume
  COUNT(*)                                                AS total_rows,
  COUNT(*) FILTER (WHERE action = TRUE
    AND status IN ('To Do','Doing'))                     AS open_actions,
  COUNT(*) FILTER (WHERE alert = TRUE
    AND status NOT IN ('Done','Cancelled','Deferred'))   AS alerts_active,

  -- Finance
  COALESCE(SUM(amount) FILTER (
    WHERE type = 'Cost'
    AND date >= date_trunc('month', CURRENT_DATE)::DATE), 0) AS monthly_burn,
  NULL::NUMERIC                                           AS available_cash,
  NULL::NUMERIC                                           AS runway_months,
  (SELECT status FROM forest_master fm2
   WHERE fm2.title ILIKE '%SAACE%'
   AND fm2.system_created = FALSE LIMIT 1)               AS saace_status,

  -- Gates
  COUNT(*) FILTER (WHERE legal_gate = 'To Clear'
    OR financial_gate = 'To Clear'
    OR gov_gate = 'To Clear'
    OR narrative_gate = 'To Clear'
    OR product_gate = 'To Clear')                        AS gates_waiting,

  -- Deadlines
  COUNT(*) FILTER (WHERE deadline BETWEEN CURRENT_DATE AND CURRENT_DATE + 7
    AND status NOT IN ('Done','Deferred','Cancelled'))   AS deadlines_this_week,
  COUNT(*) FILTER (WHERE deadline < CURRENT_DATE
    AND status NOT IN ('Done','Deferred','Cancelled'))   AS overdue,

  -- Opportunities (from forest_1ko_stats)
  (SELECT total_bets  FROM forest_1ko_stats)             AS bets_placed,
  (SELECT won         FROM forest_1ko_stats)             AS bets_won,
  (SELECT learning    FROM forest_1ko_stats)             AS bets_learned,
  (SELECT courage_meter FROM forest_1ko_stats)           AS courage_meter,
  (SELECT win_rate    FROM forest_1ko_stats)             AS win_rate,
  (SELECT learning_rate FROM forest_1ko_stats)           AS learning_rate,
  (SELECT pipeline_value FROM forest_1ko_stats)          AS pipeline_value,

  -- Recent signals (last 5 rows with signals_category set)
  (SELECT jsonb_agg(jsonb_build_object(
      'title', title, 'category', signals_category, 'date', date))
   FROM (
     SELECT title, signals_category, date FROM forest_master
     WHERE signals_category IS NOT NULL AND system_created = FALSE
     ORDER BY date DESC LIMIT 5
   ) s)                                                  AS latest_signals,

  -- Recent celebrations
  (SELECT jsonb_agg(jsonb_build_object(
      'title', title, 'date', date, 'amount', amount))
   FROM (
     SELECT title, date, amount FROM forest_master
     WHERE (celebration = TRUE OR opportunity_status = 'Success')
     AND system_created = FALSE
     ORDER BY date DESC LIMIT 3
   ) c)                                                  AS latest_celebrations,

  -- Recent key learnings
  (SELECT jsonb_agg(jsonb_build_object(
      'title', title, 'learning', key_learning, 'date', date))
   FROM (
     SELECT title, key_learning, date FROM forest_master
     WHERE key_learning IS NOT NULL AND system_created = FALSE
     ORDER BY date DESC LIMIT 3
   ) l)                                                  AS latest_learnings,

  -- Strategic relationships
  (SELECT jsonb_agg(jsonb_build_object(
      'name', entity_name, 'health', COALESCE(relationship_health,'Active'),
      'last_contact', last_contact_date,
      'needs_attention', COALESCE(relationship_health IN ('Needs Attention','At Risk'), FALSE)))
   FROM entity_registry WHERE is_strategic = TRUE)       AS strategic_relationships,

  -- Content platform health (overdue flags)
  (SELECT jsonb_object_agg(platform, is_overdue)
   FROM (
     SELECT platform,
       COALESCE((CURRENT_DATE - MAX(published_date)) > 7, TRUE) AS is_overdue
     FROM content_pipeline
     GROUP BY platform
   ) ph)                                                 AS content_platform_health

FROM forest_master
WHERE system_created = FALSE;


-- ================================================
-- SECTION 5 · get_dashboard() UNIFIED FUNCTION
-- Entry point for all 7 dashboards.
-- Note: ORDER BY + LIMIT inside scalar jsonb_agg subqueries requires
-- a wrapping subquery — direct ORDER BY triggers GROUP BY error in Postgres.
-- ================================================
CREATE OR REPLACE FUNCTION get_dashboard(
  p_dashboard TEXT,
  p_seat_slug TEXT DEFAULT 'v',
  p_period    TEXT DEFAULT 'month'
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_result       JSONB;
  v_period_start DATE;
BEGIN
  v_period_start := CASE p_period
    WHEN 'month' THEN date_trunc('month', CURRENT_DATE)::DATE
    WHEN 'ytd'   THEN date_trunc('year',  CURRENT_DATE)::DATE
    WHEN 'week'  THEN date_trunc('week',  CURRENT_DATE)::DATE
    ELSE               date_trunc('month', CURRENT_DATE)::DATE
  END;

  CASE p_dashboard

  -- ─── DASHBOARD 1: FOREST WAKE-UP ─────────────────────────
  WHEN 'wakeup' THEN
    SELECT jsonb_build_object(
      'energy', (
        SELECT jsonb_build_object(
          'energy_period', e.energy_period,
          'day_focus',     e.weekly_flow,
          'tone',          e.tone_of_day,
          'moon_phase',    e.phase_and_energy,
          'voc',           e.voc,
          'milestone',     e.milestone
        ) FROM energy e WHERE e.date = CURRENT_DATE LIMIT 1
      ),
      'snapshot', (SELECT row_to_json(fs)::jsonb FROM forest_snapshot fs),
      'my_items', (
        SELECT jsonb_agg(row_data)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'title', title, 'type', type,
            'status', status, 'priority', priority, 'deadline', deadline
          ) AS row_data
          FROM forest_master
          WHERE keeper = p_seat_slug
          AND status IN ('To Do','Doing','Agent Draft','Agent Action','Review')
          AND system_created = false
          ORDER BY
            CASE priority WHEN 'Urgent' THEN 1 WHEN 'Important' THEN 2 ELSE 3 END,
            deadline ASC NULLS LAST
          LIMIT 10
        ) sub
      ),
      'deadlines', (
        SELECT jsonb_agg(row_data)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'title', title, 'type', type,
            'deadline', deadline, 'keeper', keeper
          ) AS row_data
          FROM forest_master
          WHERE deadline BETWEEN CURRENT_DATE AND CURRENT_DATE + 14
          AND status NOT IN ('Done','Deferred','Cancelled')
          AND system_created = false
          ORDER BY deadline ASC
          LIMIT 10
        ) sub
      ),
      'recent', (
        SELECT jsonb_agg(jsonb_build_object(
          'id', id, 'title', title, 'type', type,
          'inserted_by', inserted_by, 'inserted_at', inserted_at
        ))
        FROM (
          SELECT id, title, type, inserted_by, inserted_at
          FROM forest_master
          WHERE system_created = false
          ORDER BY inserted_at DESC LIMIT 8
        ) r
      )
    ) INTO v_result;

  -- ─── DASHBOARD 2: OPPORTUNITIES + COURAGE METER ──────────
  WHEN 'opportunities' THEN
    SELECT jsonb_build_object(
      'courage_meter', (SELECT row_to_json(s)::jsonb FROM forest_1ko_stats s),
      'active_bets', (
        SELECT jsonb_agg(row_data)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'title', title, 'type', type,
            'amount', amount, 'opportunity_status', opportunity_status,
            'deadline', deadline, 'area', area
          ) AS row_data
          FROM forest_master
          WHERE opportunity_status IN ('Applied','Review','Auto Apply')
          AND system_created = false
          ORDER BY deadline ASC NULLS LAST
        ) sub
      ),
      'celebrations', (
        SELECT jsonb_agg(row_data)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'title', title, 'type', type,
            'date', date, 'amount', amount
          ) AS row_data
          FROM forest_master
          WHERE (celebration = TRUE OR opportunity_status = 'Success')
          AND system_created = false
          ORDER BY date DESC
          LIMIT 20
        ) sub
      ),
      'learnings', (
        SELECT jsonb_agg(row_data)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'title', title,
            'learning', key_learning, 'date', date, 'type', type
          ) AS row_data
          FROM forest_master
          WHERE opportunity_status = 'Learning'
          AND system_created = false
          ORDER BY date DESC
          LIMIT 20
        ) sub
      ),
      'pipeline_by_type', (
        SELECT jsonb_object_agg(COALESCE(type, 'Other'), type_stats)
        FROM (
          SELECT type,
            jsonb_build_object(
              'count', COUNT(*), 'value', COALESCE(SUM(amount), 0)
            ) AS type_stats
          FROM forest_master
          WHERE opportunity_status = 'Applied' AND system_created = false
          GROUP BY type
        ) t
      )
    ) INTO v_result;

  -- ─── DASHBOARD 3: FINANCE ────────────────────────────────
  WHEN 'finance' THEN
    SELECT jsonb_build_object(
      'annual_goal',         36000,
      'revenue_ytd', COALESCE((
        SELECT SUM(amount) FROM forest_master
        WHERE type IN ('Entry','Contract')
        AND amount_type ILIKE '%revenue%'
        AND date >= date_trunc('year', CURRENT_DATE)::DATE
        AND system_created = false), 0),
      'monthly_target',      ROUND(36000.0 / 12, 0),
      'revenue_this_month', COALESCE((
        SELECT SUM(amount) FROM forest_master
        WHERE type IN ('Entry','Contract')
        AND amount_type ILIKE '%revenue%'
        AND date >= v_period_start
        AND system_created = false), 0),
      'monthly_burn', COALESCE((
        SELECT SUM(amount) FROM forest_master
        WHERE type = 'Cost'
        AND date >= v_period_start
        AND system_created = false), 0),
      'runway_months',       NULL,
      'saace_status', (
        SELECT status FROM forest_master
        WHERE title ILIKE '%SAACE%' AND system_created = false LIMIT 1),
      'pipeline_value', (
        SELECT COALESCE(SUM(amount), 0) FROM forest_master
        WHERE opportunity_status = 'Applied' AND system_created = false),
      'pipeline_count', (
        SELECT COUNT(*) FROM forest_master
        WHERE opportunity_status = 'Applied' AND system_created = false),
      'proposals_total', COALESCE((
        SELECT SUM(amount) FROM forest_master
        WHERE type = 'Proposal' AND amount IS NOT NULL
        AND system_created = false), 0),
      'clients_active', (
        SELECT COUNT(*) FROM entity_registry
        WHERE entity_type @> ARRAY['Client']
        AND relationship_status = 'Active'),
      'opex_by_area', (
        SELECT jsonb_object_agg(COALESCE(area, 'Unassigned'), area_total)
        FROM (
          SELECT area, SUM(amount) AS area_total
          FROM forest_master
          WHERE type = 'Cost'
          AND EXTRACT(year FROM date) = EXTRACT(year FROM CURRENT_DATE)
          AND system_created = false
          GROUP BY area
        ) t),
      'open_financial_gates', (
        SELECT COUNT(*) FROM forest_master
        WHERE financial_gate = 'To Clear' AND system_created = false)
    ) INTO v_result;

  -- ─── DASHBOARD 4: CONTENT ────────────────────────────────
  WHEN 'content' THEN
    SELECT get_content_metrics() INTO v_result;

  -- ─── DASHBOARD 5: LEGAL + ENTITIES ───────────────────────
  WHEN 'legal' THEN
    SELECT jsonb_build_object(
      'contracts', jsonb_build_object(
        'total', (
          SELECT COUNT(*) FROM forest_master
          WHERE type = 'Contract' AND system_created = false),
        'active', (
          SELECT COUNT(*) FROM forest_master
          WHERE type = 'Contract' AND status = 'Doing'
          AND system_created = false),
        'pending_signature', (
          SELECT COUNT(*) FROM forest_master
          WHERE type = 'Contract' AND status = 'Review'
          AND system_created = false),
        'draft', (
          SELECT COUNT(*) FROM forest_master
          WHERE type = 'Contract'
          AND status IN ('To Do','Agent Draft')
          AND system_created = false),
        'expiring_90d', (
          SELECT COUNT(*) FROM forest_master
          WHERE type = 'Contract'
          AND return_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 90
          AND system_created = false)
      ),
      'open_legal_gates', (
        SELECT COUNT(*) FROM forest_master
        WHERE legal_gate = 'To Clear' AND system_created = false),
      'entities', (
        SELECT jsonb_agg(jsonb_build_object(
          'name', entity_name, 'type', entity_type,
          'status', relationship_status, 'jurisdiction', jurisdiction,
          'registration', registration_number,
          'health', relationship_health,
          'last_contact', last_contact_date,
          'is_strategic', is_strategic
        ) ORDER BY is_strategic DESC, entity_name ASC)
        FROM entity_registry),
      'strategic_relationships', (
        SELECT jsonb_agg(jsonb_build_object(
          'name', entity_name,
          'health', COALESCE(relationship_health, 'Active'),
          'last_contact', last_contact_date,
          'needs_attention', COALESCE(
            relationship_health IN ('Needs Attention','At Risk'), FALSE)
        ) ORDER BY
          CASE relationship_health
            WHEN 'At Risk'         THEN 1
            WHEN 'Needs Attention' THEN 2
            ELSE 3 END,
          last_contact_date ASC NULLS FIRST)
        FROM entity_registry WHERE is_strategic = TRUE),
      'jurisdictions', (
        SELECT jsonb_agg(jsonb_build_object(
          'code', legal_ref, 'name', name, 'definition', definition))
        FROM legal_table WHERE section = 'Jurisdiction'),
      'applications_in_progress', (
        SELECT jsonb_agg(row_data)
        FROM (
          SELECT jsonb_build_object(
            'id', id, 'title', title, 'status', status,
            'deadline', deadline, 'library_id', forest_library_link
          ) AS row_data
          FROM forest_master
          WHERE type = 'Application'
          AND status NOT IN ('Done','Cancelled','Deferred')
          AND system_created = false
          ORDER BY deadline ASC NULLS LAST
        ) sub
      )
    ) INTO v_result;

  -- ─── DASHBOARD 6: ACADEMIC + IP ──────────────────────────
  WHEN 'academic' THEN
    SELECT jsonb_build_object(
      'publications', jsonb_build_object(
        'live', (
          SELECT COUNT(*) FROM forest_master
          WHERE doi_gate = 'Live' AND system_created = false),
        'in_pipeline', (
          SELECT COUNT(*) FROM forest_master
          WHERE doi_gate IN ('Flagged','Agent Draft','Review','Submitted')
          AND system_created = false),
        'orcid_linked', (
          SELECT COUNT(*) FROM forest_master
          WHERE doi_gate = 'ORCID Linked' AND system_created = false),
        'cited', (
          SELECT COUNT(*) FROM forest_master
          WHERE doi_gate = 'Cited' AND system_created = false)
      ),
      'applications', jsonb_build_object(
        'targeted', (
          SELECT COUNT(*) FROM forest_master
          WHERE type = 'Application' AND area = 'Academic'
          AND system_created = false),
        'in_progress', (
          SELECT COUNT(*) FROM forest_master
          WHERE type = 'Application' AND area = 'Academic'
          AND status IN ('Doing','Review') AND system_created = false),
        'applied', (
          SELECT COUNT(*) FROM forest_master
          WHERE type = 'Application' AND area = 'Academic'
          AND opportunity_status = 'Applied' AND system_created = false),
        'won', (
          SELECT COUNT(*) FROM forest_master
          WHERE type = 'Application' AND area = 'Academic'
          AND opportunity_status = 'Success' AND system_created = false)
      ),
      'library_docs', (
        SELECT COUNT(*) FROM forest_library
        WHERE books @> ARRAY['Academic']),
      'research_active', (
        SELECT COUNT(*) FROM forest_master
        WHERE type = 'Research/R&D' AND status = 'Doing'
        AND system_created = false),
      'ip_assets', (SELECT COUNT(*) FROM ip_assets_knowledge),
      'open_doi_gates', (
        SELECT COUNT(*) FROM forest_master
        WHERE doi_gate NOT IN ('Not Applicable','Live','ORCID Linked','Cited')
        AND doi_gate IS NOT NULL AND system_created = false)
    ) INTO v_result;

  -- ─── DASHBOARD 7: OPERATIONS ─────────────────────────────
  WHEN 'operations' THEN
    SELECT jsonb_build_object(
      'open_actions', (
        SELECT COUNT(*) FROM forest_master
        WHERE action = TRUE AND status IN ('To Do','Doing')
        AND system_created = false),
      'overdue', (
        SELECT COUNT(*) FROM forest_master
        WHERE deadline < CURRENT_DATE
        AND status NOT IN ('Done','Deferred','Cancelled')
        AND system_created = false),
      'due_this_week', (
        SELECT COUNT(*) FROM forest_master
        WHERE deadline BETWEEN CURRENT_DATE AND CURRENT_DATE + 7
        AND status NOT IN ('Done','Deferred','Cancelled')
        AND system_created = false),
      'done_this_month', (
        SELECT COUNT(*) FROM forest_master
        WHERE status = 'Done'
        AND date_trunc('month', last_updated) = date_trunc('month', CURRENT_DATE)
        AND system_created = false),
      'gates_by_type', jsonb_build_object(
        'legal', (
          SELECT COUNT(*) FROM forest_master
          WHERE legal_gate = 'To Clear' AND system_created = false),
        'financial', (
          SELECT COUNT(*) FROM forest_master
          WHERE financial_gate = 'To Clear' AND system_created = false),
        'governance', (
          SELECT COUNT(*) FROM forest_master
          WHERE gov_gate = 'To Clear' AND system_created = false),
        'narrative', (
          SELECT COUNT(*) FROM forest_master
          WHERE narrative_gate = 'To Clear' AND system_created = false),
        'product', (
          SELECT COUNT(*) FROM forest_master
          WHERE product_gate = 'To Clear' AND system_created = false)
      ),
      'by_area', (
        SELECT jsonb_object_agg(COALESCE(area, 'Unassigned'), area_count)
        FROM (
          SELECT area, COUNT(*) AS area_count
          FROM forest_master
          WHERE status IN ('To Do','Doing') AND system_created = false
          GROUP BY area
        ) t),
      'by_seat', (
        SELECT jsonb_object_agg(COALESCE(keeper, 'Unassigned'), keeper_count)
        FROM (
          SELECT keeper, COUNT(*) AS keeper_count
          FROM forest_master
          WHERE status IN ('To Do','Doing') AND system_created = false
          GROUP BY keeper
        ) t)
    ) INTO v_result;

  ELSE
    v_result := jsonb_build_object(
      'error', 'Unknown dashboard: ' || p_dashboard,
      'valid_dashboards', jsonb_build_array(
        'wakeup','opportunities','finance',
        'content','legal','academic','operations')
    );
  END CASE;

  RETURN v_result;
END;
$$;
