-- OAK PROTOCOL · Canary: SEQUOIA14APRIL
-- Deployed: 27 April 2026
-- OKKA Expanded Intelligence OÜ

CREATE OR REPLACE FUNCTION set_current_canary(
  new_canary   TEXT,
  what_changed TEXT DEFAULT NULL,
  sealed_by    TEXT DEFAULT 'V'
)
RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
  UPDATE forest_now SET canary = new_canary, updated_at = NOW();
  INSERT INTO canary (canary_code, canary_type, date, what_changed, sealed_by)
  VALUES (new_canary, 'tree', CURRENT_DATE, what_changed, sealed_by);
  RETURN 'Canary set to ' || new_canary;
END;
$$;

CREATE OR REPLACE FUNCTION refresh_forest_now()
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
  v_energy_period TEXT;
  v_day_focus     TEXT;
  v_next_deadline TEXT;
BEGIN
  SELECT energy_period, weekly_flow INTO v_energy_period, v_day_focus
  FROM energy WHERE date = CURRENT_DATE LIMIT 1;

  SELECT title INTO v_next_deadline
  FROM forest_master
  WHERE deadline IS NOT NULL AND deadline >= CURRENT_DATE
    AND status NOT IN ('Done','Deferred','Cancelled')
  ORDER BY deadline ASC LIMIT 1;

  UPDATE forest_now SET
    snapshot_date = CURRENT_DATE,
    energy_period = v_energy_period,
    day_focus     = v_day_focus,
    next_deadline = v_next_deadline,
    updated_at    = NOW();

  RETURN 'forest_now refreshed at ' || NOW()::TEXT;
END;
$$;

-- forest_wakeup: parameterised by seat_slug. Returns JSONB with 6 blocks.
-- Call: SELECT forest_wakeup('v'); — or any seat slug.
-- Note: uses subquery in Block 6 to avoid GROUP BY conflict with jsonb_agg ORDER BY.
CREATE OR REPLACE FUNCTION forest_wakeup(
  p_seat_slug TEXT DEFAULT 'v'
)
RETURNS JSONB LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_today     JSONB;
  v_alerts    JSONB;
  v_vitals    JSONB;
  v_deadlines JSONB;
  v_my_items  JSONB;
  v_recent    JSONB;
BEGIN
  SELECT jsonb_build_object(
    'date', CURRENT_DATE, 'energy_period', e.energy_period,
    'day_focus', e.weekly_flow, 'tone', e.tone_of_day,
    'moon_in_sign', e.moon_in_sign, 'phase_and_energy', e.phase_and_energy,
    'voc', e.voc, 'astrological_event', e.astrological_evt,
    'op_direction', e.op_direction, 'period_phase', e.period_phase,
    'milestone', e.milestone, 'period_tracking', e.period_tracking
  ) INTO v_today FROM energy e WHERE e.date = CURRENT_DATE LIMIT 1;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', a.id, 'event_type', a.event_type, 'description', a.event_desc,
    'fm_row_link', a.fm_row_link, 'seat_target', a.seat_target, 'created_at', a.created_at
  ) ORDER BY a.created_at DESC), '[]'::jsonb)
  INTO v_alerts FROM alerts a WHERE a.acknowledged = FALSE;

  SELECT jsonb_build_object(
    'bets_placed', s.bets_placed, 'bets_won', s.bets_won,
    'win_rate', COALESCE(s.win_rate, 0), 'goal_progress', COALESCE(s.goal_progress, 0),
    'remaining_bets', s.remaining_bets,
    'active_library_docs', (SELECT COUNT(*) FROM forest_library WHERE status != 'To Create'),
    'active_fm_rows', (SELECT COUNT(*) FROM forest_master WHERE status NOT IN ('Done','Cancelled','Deferred')),
    'open_gates', (SELECT COUNT(*) FROM forest_master WHERE
      legal_gate = 'To Clear' OR financial_gate = 'To Clear' OR gov_gate = 'To Clear'
      OR narrative_gate = 'To Clear' OR product_gate = 'To Clear')
  ) INTO v_vitals FROM forest_1ko_stats s;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', id, 'title', title, 'deadline', deadline,
    'status', status, 'priority', priority, 'keeper', keeper, 'fm_type', fm_type
  ) ORDER BY deadline ASC), '[]'::jsonb)
  INTO v_deadlines FROM forest_master_live
  WHERE deadline IS NOT NULL AND deadline - CURRENT_DATE <= 14
    AND deadline >= CURRENT_DATE AND status NOT IN ('Done','Deferred','Cancelled')
  LIMIT 20;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', id, 'title', title, 'status', status, 'priority', priority,
    'deadline', deadline, 'fm_type', fm_type, 'computed_alert', computed_alert
  ) ORDER BY
    CASE priority WHEN 'Urgent' THEN 1 WHEN 'Important' THEN 2 WHEN 'Regular' THEN 3 WHEN 'Low' THEN 4 ELSE 5 END,
    deadline ASC NULLS LAST
  ), '[]'::jsonb)
  INTO v_my_items FROM forest_master_live
  WHERE keeper = p_seat_slug AND status IN ('To Do','Doing','Agent Draft','Agent Action','Review')
  LIMIT 20;

  -- Subquery required: mixing jsonb_agg ORDER BY with outer ORDER BY causes GROUP BY conflict
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', r.id, 'title', r.title, 'fm_type', r.fm_type,
    'status', r.status, 'inserted_by', r.inserted_by, 'inserted_at', r.inserted_at
  )), '[]'::jsonb)
  INTO v_recent
  FROM (SELECT id, title, fm_type, status, inserted_by, inserted_at
        FROM forest_master ORDER BY inserted_at DESC LIMIT 10) r;

  RETURN jsonb_build_object(
    'today', COALESCE(v_today, '{}'::jsonb),
    'alerts', COALESCE(v_alerts, '[]'::jsonb),
    'vitals', COALESCE(v_vitals, '{}'::jsonb),
    'deadlines', COALESCE(v_deadlines, '[]'::jsonb),
    'my_items', COALESCE(v_my_items, '[]'::jsonb),
    'recent', COALESCE(v_recent, '[]'::jsonb),
    'seat', p_seat_slug,
    'generated_at', NOW()
  );
END;
$$;

-- forest_handle_bidirectional_entry: atomic stored procedure.
-- Called by the handle-bidirectional-entry Edge Function.
-- Loop guard: system_created = TRUE rows are skipped immediately.
-- Status sync guard: value equality check before any UPDATE.
CREATE OR REPLACE FUNCTION forest_handle_bidirectional_entry(
  p_source_table TEXT,
  p_source_id    UUID,
  p_entry_type   TEXT,
  p_seat_slug    TEXT DEFAULT 'v'
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_fm_row         forest_master%ROWTYPE;
  v_lib_row        forest_library%ROWTYPE;
  v_new_fm_id      UUID;
  v_new_lib_id     UUID;
  v_requires_lib   BOOLEAN := FALSE;
  v_current_canary TEXT;
  v_lib_row_type   TEXT;
BEGIN
  SELECT canary INTO v_current_canary FROM forest_now LIMIT 1;

  IF p_source_table = 'forest_master' THEN
    SELECT * INTO v_fm_row FROM forest_master WHERE id = p_source_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('status','error','reason','FM row not found: ' || p_source_id);
    END IF;
    IF v_fm_row.system_created = TRUE THEN
      RETURN jsonb_build_object('status','skipped','reason','system_created — no propagation');
    END IF;

    v_requires_lib := v_fm_row.fm_type IN (
      'Chronicle','Roundtable','Narrative','Decision','Record',
      'Seat Chronicle','Publication','Grant','Contract'
    );
    v_lib_row_type := CASE v_fm_row.fm_type
      WHEN 'Chronicle'      THEN 'Chronicle'
      WHEN 'Roundtable'     THEN 'Roundtable'
      WHEN 'Seat Chronicle' THEN 'Chronicle'
      WHEN 'Narrative'      THEN 'Chronicle'
      WHEN 'Decision'       THEN 'Chronicle'
      WHEN 'Record'         THEN 'Chronicle'
      WHEN 'Contract'       THEN 'Legal Record'
      WHEN 'Publication'    THEN 'Publication Record'
      WHEN 'Grant'          THEN 'Chronicle'
      ELSE 'Chronicle'
    END;

    IF v_requires_lib AND v_fm_row.library_link IS NULL THEN
      INSERT INTO forest_library (
        document_title, full_document, date, row_type, status,
        fm_row_link, inserted_by, system_created, canary, fm_status, append_on
      ) VALUES (
        v_fm_row.title,
        COALESCE(v_fm_row.description, '— Stub created by bidirectional entry.'),
        CURRENT_DATE, v_lib_row_type, 'To Create',
        p_source_id, p_seat_slug, TRUE,
        COALESCE(v_current_canary, 'SEQUOIA14APRIL'), 'To Create', FALSE
      ) RETURNING id INTO v_new_lib_id;

      UPDATE forest_master SET
        library_link = v_new_lib_id::TEXT, library_status = 'To Create', updated_at = NOW()
      WHERE id = p_source_id;

      INSERT INTO forest_library_change_log (
        library_row_id, event_type, author, change_summary, canary, triggered_by_fm
      ) VALUES (
        v_new_lib_id, 'Created', p_seat_slug,
        'Stub created by bidirectional entry from FM: ' || p_source_id,
        COALESCE(v_current_canary, 'SEQUOIA14APRIL'), p_source_id
      );

      INSERT INTO alerts (fm_row_link, lib_row_link, event_type, event_desc, seat_target)
      VALUES (p_source_id, v_new_lib_id, 'Library Stub Created',
        'Document stub created for: ' || v_fm_row.title, COALESCE(v_fm_row.keeper, p_seat_slug));
    END IF;

  ELSIF p_source_table = 'forest_library' THEN
    SELECT * INTO v_lib_row FROM forest_library WHERE id = p_source_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('status','error','reason','Library row not found: ' || p_source_id);
    END IF;
    IF v_lib_row.system_created = TRUE THEN
      RETURN jsonb_build_object('status','skipped','reason','system_created — no propagation');
    END IF;

    IF v_lib_row.fm_row_link IS NULL THEN
      INSERT INTO forest_master (
        title, fm_type, status, priority, inserted_by,
        library_link, library_status, system_created, canary, is_action
      ) VALUES (
        v_lib_row.document_title, 'Record', 'Done', 'Regular', p_seat_slug,
        p_source_id::TEXT, 'Created', TRUE,
        COALESCE(v_current_canary, 'SEQUOIA14APRIL'), FALSE
      ) RETURNING id INTO v_new_fm_id;

      UPDATE forest_library SET
        fm_row_link = v_new_fm_id, fm_status = 'Created', updated_at = NOW()
      WHERE id = p_source_id
        AND (fm_row_link IS DISTINCT FROM v_new_fm_id OR fm_status IS DISTINCT FROM 'Created');

      INSERT INTO forest_library_change_log (library_row_id, event_type, author, change_summary, canary)
      VALUES (p_source_id, 'Created', p_seat_slug,
        'Document created. FM record auto-generated: ' || v_new_fm_id,
        COALESCE(v_current_canary, 'SEQUOIA14APRIL'));
    END IF;

  ELSE
    RETURN jsonb_build_object('status','error','reason','Unknown source_table: ' || p_source_table);
  END IF;

  RETURN jsonb_build_object(
    'status', 'success', 'source_id', p_source_id,
    'fm_id', COALESCE(v_new_fm_id, p_source_id), 'library_id', v_new_lib_id
  );

EXCEPTION WHEN OTHERS THEN
  INSERT INTO alerts (event_type, event_desc)
  VALUES ('System Write Failure',
    'bidirectional entry failed · source=' || p_source_table || ' · ' || SQLERRM);
  RAISE;
END;
$$;
