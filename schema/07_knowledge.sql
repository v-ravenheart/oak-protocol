-- OAK PROTOCOL · Knowledge Layer
-- Canary: OAK5MAY · Built: 5 May 2026
-- OKKA Expanded Intelligence OÜ
--
-- Single table for Books, Principles, and IP entries.
-- type field determines which fields are relevant per row.
--
-- Migrations 18-21 in Serena Supabase (bpxgeaycrfsxqoqfakqj)
--
-- Sections:
--   1. knowledge_entries table + triggers + indexes + RLS
--   2. Content alert trigger → Forest Master + alerts
--   3. Views: knowledge_books, knowledge_principles, knowledge_ip,
--             knowledge_content_queue
--   4. Vocabulary seed: books, principle frameworks, IP series


-- ================================================
-- SECTION 1 · knowledge_entries TABLE
-- ================================================

CREATE TABLE IF NOT EXISTS knowledge_entries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- CLASSIFICATION
  type TEXT NOT NULL CHECK (type IN ('Book', 'Principle', 'IP')),

  -- HIERARCHY
  -- Books:      parent = book name, chapter = chapter, subchapter = subchapter
  -- Principles: parent = framework name, chapter = principle name
  -- IP:         parent = series name, chapter = entry title
  parent     TEXT,    -- Book name / Framework name / IP Series
  title      TEXT NOT NULL,
  chapter    TEXT,    -- Chapter name or number
  subchapter TEXT,    -- Subchapter (Books only)

  -- CONTENT FIELDS
  root_law    TEXT,    -- Principles only: the governing statement
  doi         TEXT,    -- IP only: Zenodo DOI
  publish_url TEXT,    -- IP only: link to live publication
  content     TEXT,
  word_count  INTEGER GENERATED ALWAYS AS (
    array_length(string_to_array(trim(content), ' '), 1)
  ) STORED,

  -- BOOK/MANUSCRIPT LIFECYCLE
  content_status TEXT DEFAULT 'To Write'
    CHECK (content_status IN (
      'To Write', 'Writing', 'To Review', 'To Publish', 'Published'
    )),
  publish_link TEXT,   -- Link to published version
  zenodo_entry TEXT,   -- Zenodo entry ID if published there

  -- CONTENT/SOCIAL ALERT STATUS
  -- When set, triggers a Forest Master task for Frankie Content
  -- and an alert for Frankie Master.
  content_alert TEXT CHECK (content_alert IN (
    'To Write', 'Writing', 'To Review', 'To Post', 'Scheduled', 'Posted'
  )),
  content_alert_links     TEXT[],   -- Links to posted content
  content_alert_scheduled DATE,     -- When scheduled to post

  -- GOVERNANCE
  status TEXT NOT NULL DEFAULT 'To Write'
    CHECK (status IN (
      'To Write', 'Writing', 'To Review', 'V Sealed', 'Published'
    )),
  sealed BOOLEAN NOT NULL DEFAULT FALSE,
  author TEXT[],   -- seat slug(s)

  -- CANARY — set automatically by trg_ke_canary on INSERT
  -- via get_current_canary() — do not set manually
  canary TEXT DEFAULT 'OAK5MAY',

  -- LINKS
  fm_row_link  UUID,   -- links to forest_master row
  library_link UUID,   -- links to forest_library row

  -- METADATA
  display_order  INTEGER,   -- for ordering within parent/chapter
  tags           TEXT[],
  notes          TEXT,
  inserted_by    TEXT,
  system_created BOOLEAN NOT NULL DEFAULT FALSE,
  inserted_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ── CANARY AUTO-SET TRIGGER ──────────────────────────────────
-- Calls get_current_canary() on every INSERT so rows always
-- carry the live constitutional version, not the table default.
CREATE OR REPLACE FUNCTION ke_set_canary()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.canary := get_current_canary();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ke_canary
  BEFORE INSERT ON knowledge_entries
  FOR EACH ROW EXECUTE FUNCTION ke_set_canary();

-- ── UPDATED_AT TRIGGER ───────────────────────────────────────
CREATE OR REPLACE FUNCTION ke_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ke_updated_at
  BEFORE UPDATE ON knowledge_entries
  FOR EACH ROW EXECUTE FUNCTION ke_set_updated_at();

-- ── INDEXES ──────────────────────────────────────────────────
CREATE INDEX idx_ke_type          ON knowledge_entries(type);
CREATE INDEX idx_ke_parent        ON knowledge_entries(parent);
CREATE INDEX idx_ke_status        ON knowledge_entries(status);
CREATE INDEX idx_ke_content_alert ON knowledge_entries(content_alert)
  WHERE content_alert IS NOT NULL;
CREATE INDEX idx_ke_doi           ON knowledge_entries(doi)
  WHERE doi IS NOT NULL;

-- ── RLS ──────────────────────────────────────────────────────
ALTER TABLE knowledge_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "auth_full_access" ON knowledge_entries
  FOR ALL TO authenticated USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "anon_read" ON knowledge_entries
  FOR SELECT TO anon USING (TRUE);

GRANT SELECT ON knowledge_entries TO anon, authenticated;


-- ================================================
-- SECTION 2 · CONTENT ALERT TRIGGER
-- When content_alert changes, auto-creates a Forest Master task
-- for Frankie Content and an alert for Frankie Master.
-- SECURITY DEFINER to allow access to auth.users.
-- system_created = TRUE on all generated FM rows — no loop.
-- ================================================

CREATE OR REPLACE FUNCTION ke_content_alert_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid UUID;
BEGIN
  -- Only fire when content_alert is newly set or changed
  IF (NEW.content_alert IS NOT NULL) AND
     (OLD.content_alert IS DISTINCT FROM NEW.content_alert) THEN

    -- Try to get V's auth UUID (null-safe if not found)
    SELECT id INTO v_uid
    FROM auth.users
    WHERE email = 'its.v@okka.ai'
    LIMIT 1;

    -- Create Forest Master task for Frankie Content
    INSERT INTO forest_master (
      owner_id, title, type, status, priority,
      oak_part, area, keeper, action,
      description, canary, inserted_by, system_created
    ) VALUES (
      v_uid,
      'Content Alert: ' || NEW.title || ' — ' || NEW.content_alert,
      'Content', 'To Do', 'Regular',
      'Trunk', 'Narrative',
      'frankie-content', TRUE,
      'Knowledge entry requires content action. Type: ' ||
        NEW.type || '. Parent: ' || COALESCE(NEW.parent, 'N/A') ||
        '. Status: ' || NEW.content_alert ||
        CASE WHEN NEW.content_alert_scheduled IS NOT NULL
          THEN '. Scheduled: ' || NEW.content_alert_scheduled::TEXT
          ELSE ''
        END,
      get_current_canary(),
      'system', TRUE
    );

    -- Alert for Frankie Master
    INSERT INTO alerts (event_type, event_desc, seat_target)
    VALUES (
      'Content Alert',
      'Knowledge entry needs content: ' || NEW.title ||
        ' (' || NEW.type || ') — ' || NEW.content_alert,
      'frankie-master'
    );

  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_ke_content_alert
  AFTER INSERT OR UPDATE ON knowledge_entries
  FOR EACH ROW EXECUTE FUNCTION ke_content_alert_trigger();


-- ================================================
-- SECTION 3 · VIEWS
-- ================================================

-- Books: ordered by parent book, display_order, chapter
CREATE OR REPLACE VIEW knowledge_books AS
SELECT * FROM knowledge_entries
WHERE type = 'Book'
ORDER BY parent, display_order NULLS LAST, chapter, subchapter;

-- Principles: ordered by framework, display_order
CREATE OR REPLACE VIEW knowledge_principles AS
SELECT * FROM knowledge_entries
WHERE type = 'Principle'
ORDER BY parent, display_order NULLS LAST, chapter;

-- IP registry: ordered by series, newest first
CREATE OR REPLACE VIEW knowledge_ip AS
SELECT * FROM knowledge_entries
WHERE type = 'IP'
ORDER BY parent, inserted_at DESC;

-- Content pipeline from knowledge entries
-- Everything with a content_alert set and not yet Posted
CREATE OR REPLACE VIEW knowledge_content_queue AS
SELECT
  id, type, parent, title, chapter,
  content_alert, content_alert_scheduled,
  content_alert_links, status,
  fm_row_link, canary, updated_at
FROM knowledge_entries
WHERE content_alert IS NOT NULL
  AND content_alert NOT IN ('Posted')
ORDER BY
  CASE content_alert
    WHEN 'To Post'   THEN 1
    WHEN 'Scheduled' THEN 2
    WHEN 'To Review' THEN 3
    WHEN 'Writing'   THEN 4
    WHEN 'To Write'  THEN 5
  END,
  content_alert_scheduled ASC NULLS LAST;

GRANT SELECT ON knowledge_books         TO anon, authenticated;
GRANT SELECT ON knowledge_principles    TO anon, authenticated;
GRANT SELECT ON knowledge_ip            TO anon, authenticated;
GRANT SELECT ON knowledge_content_queue TO anon, authenticated;


-- ================================================
-- SECTION 4 · VOCABULARY SEED
-- Populates maestro_vocabulary parent dropdowns for the UI.
-- UNIQUE constraint on (vocab_type, name) — safe to re-run.
-- ================================================

INSERT INTO maestro_vocabulary (vocab_type, name, definition, display_order, active)
VALUES
  -- Books (5 volumes)
  ('knowledge_parent_book',
   'Book 1: The Self',
   'Understanding oneself — ADHD Dance, This Brain of Mine',
   1, TRUE),
  ('knowledge_parent_book',
   'Book 2: The Body',
   'Emotional health, physical health, routine and structure',
   2, TRUE),
  ('knowledge_parent_book',
   'Book 3: The Tribe',
   'Friendships, romantic love, family',
   3, TRUE),
  ('knowledge_parent_book',
   'Book 4: The Work and the World',
   'Career, finances, what we build and how',
   4, TRUE),
  ('knowledge_parent_book',
   'Book 5: The Meaning',
   'Leisure, self-connection, spirituality, self-sovereignty',
   5, TRUE),

  -- Principle frameworks
  ('knowledge_parent_principle',
   'Seven Lenses',
   'OKKA research framework — 7 perspectives on expansion',
   1, TRUE),
  ('knowledge_parent_principle',
   'OAK Protocol Principles',
   'Governing principles of the OAK Protocol',
   2, TRUE),
  ('knowledge_parent_principle',
   'Root Laws',
   'Foundational constitutional rules of the organism',
   3, TRUE),

  -- IP Series (Zenodo)
  ('knowledge_parent_ip',
   'OKKA Expanded Intelligence Series',
   'Master series DOI: 10.5281/zenodo.19086615',
   1, TRUE),
  ('knowledge_parent_ip',
   'Seven Lenses Series',
   'DOI: 10.5281/zenodo.19125553',
   2, TRUE),
  ('knowledge_parent_ip',
   'House of Us Programme',
   'DOI: 10.5281/zenodo.19233480',
   3, TRUE),
  ('knowledge_parent_ip',
   'Awesome Minds Series',
   'DOI: 10.5281/zenodo.19233969',
   4, TRUE)

ON CONFLICT (vocab_type, name) DO NOTHING;
