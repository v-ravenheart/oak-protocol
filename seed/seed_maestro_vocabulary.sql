-- OAK PROTOCOL · Canary: SEQUOIA14APRIL
-- Deployed: 27 April 2026
-- OKKA Expanded Intelligence OÜ
-- seed/seed_maestro_vocabulary.sql
-- Canonical dropdown values for Forest Master and Forest Library.
-- Run after 04_rls.sql.

-- ================================================
-- SECTION A — FOREST MASTER TYPES (26 values)
-- vocab_type = 'fm_type'
-- These are the values for the fm_type column.
-- No type is valid without an entry here.
-- ================================================
INSERT INTO maestro_vocabulary (vocab_type, name, definition, display_order) VALUES

('fm_type', 'Grant',
 'Funding application with a hard external deadline. Requires Financial Gate review when co-financing applies.',
 1),

('fm_type', 'Application',
 'Programme or accelerator to join. YC, residencies, fellowships. Requires Freya alert on creation.',
 2),

('fm_type', 'Contract',
 'Legal agreement to draft or sign. Auto-sets Legal Gate to To Clear. Wolf keeper.',
 3),

('fm_type', 'Publication',
 'Zenodo upload, Substack post, academic paper, or DOI registration. Doctor M keeper for academic.',
 4),

('fm_type', 'Meeting',
 'Named person or institution meeting. Creates Calendar event when Calendar field is set.',
 5),

('fm_type', 'Build',
 'Product sprint or feature build for Lova. Auto-sets Product Gate to To Clear. Ventura Hep keeper.',
 6),

('fm_type', 'Content',
 'Social post, field note, article, or any content for publishing. Creates Content Pipeline stub.',
 7),

('fm_type', 'Contact',
 'Message or email action. A communication that needs to happen.',
 8),

('fm_type', 'Scout',
 'Bounded investigation. Research with a deliverable and a deadline. Not open-ended.',
 9),

('fm_type', 'Admin',
 'Operational housekeeping. Subscriptions, registrations, renewals, logistics.',
 10),

('fm_type', 'Proposal',
 'Formal proposal document for a client, partner, or investor.',
 11),

('fm_type', 'Decision',
 'Sealed decision. Immutable record of a choice made. Creates Library stub automatically.',
 12),

('fm_type', 'Research/R&D',
 'Ongoing research or R&D activity. Lives in Roots collection. Doctor M and Deep Reader keepers.',
 13),

('fm_type', 'Idea',
 'Concept not yet formalised. No deadline. No action required. Captured for future use.',
 14),

('fm_type', 'Reference',
 'External reference — article, tool, resource, person — worth remembering.',
 15),

('fm_type', 'Target',
 'Goal or milestone target. Quantified and dated. Different from a Milestone (which is an achievement).',
 16),

('fm_type', 'Milestone',
 'Significant achievement reached. Creates Calendar event when Forest Roadmap = TRUE.',
 17),

('fm_type', 'Entry',
 'General register entry. When nothing else fits. Use sparingly.',
 18),

('fm_type', 'Cost',
 'Operational expense. Amount field = EUR amount. Amount Type = cost category.',
 19),

('fm_type', 'Tool',
 'Software subscription or tool the organism uses. Tracks cost and renewal.',
 20),

('fm_type', 'Narrative',
 'Company story or cultural record. Cross-domain. DOI-able via Zenodo. Frankie Master keeper.',
 21),

('fm_type', 'Record',
 'Formal legal or governance record. Creates Library stub automatically.',
 22),

('fm_type', 'Roundtable',
 'Multi-seat organism deliberation. Creates Library stub with Entry ID automatically.',
 23),

('fm_type', 'Seat Chronicle',
 'Session record for a specific seat. Creates Library stub automatically. Seat keeper writes.',
 24),

('fm_type', 'News',
 'External news item or organism announcement. Alert fires on day of insertion. Frankie Master notified.',
 25),

('fm_type', 'Visual Identity',
 'Brand asset — logo, colour system, typography, visual. Frankie Branding keeper.',
 26),

('fm_type', 'Other',
 'Does not fit any of the above types. Flag for Il Maestro to review and recategorise.',
 27);

-- ================================================
-- SECTION B — FOREST LIBRARY DOCUMENT TYPES
-- vocab_type = 'library_type'
-- These values map to row_type and document_type fields.
-- Each type has a Drive folder path.
-- ================================================
INSERT INTO maestro_vocabulary
  (vocab_type, name, definition, drive_folder, display_order) VALUES

('library_type', 'Chronicle',
 'Session record. One per significant session. Append-only. Legal quality narrative. What happened, what was decided, why.',
 '02. BY TYPE/01. CHRONICLES', 1),

('library_type', 'First Page',
 'A book''s founding identity document. Fixed. Immutable. Contains seat identity, trust tier, system prompt summary, rules of engagement, founding canary. Produced by Il Maestro.',
 '02. BY TYPE/03. BOOKS · First Pages', 2),

('library_type', 'Working Document',
 'A seat''s live scratchpad. One per seat. Append On = TRUE. Never seals. Full replace each session. Current state only.',
 '01. BY SEAT', 3),

('library_type', 'Roundtable',
 'Full roundtable record. Multi-seat deliberation with Entry ID. Append-only until formally closed.',
 '02. BY TYPE/04. ROUNDTABLES', 4),

('library_type', 'Roundtable Verse',
 'Per-seat delivery of roundtable context. One row per seat per roundtable. Solves copy-paste problem between browser chats.',
 '02. BY TYPE/04. ROUNDTABLES', 5),

('library_type', 'Legal Record',
 'Formal legal review record. Produced when Legal Gate is cleared. Immutable. Linked to FM row via Legal Gate FM ID.',
 '02. BY TYPE/06. LEGAL RECORDS', 6),

('library_type', 'SoC',
 'Shape of Choice observation. Records voice system evolution. Every change to how a seat speaks.',
 '01. BY SEAT', 7),

('library_type', 'Publication Record',
 'Academic publication record. Produced when DOI Gate = Live. Contains DOI, ORCID status, citation info.',
 '02. BY TYPE/08. PUBLICATIONS · DOI', 8),

('library_type', 'Principle',
 'A governing rule or belief. Lives in Roots / Principles and Root Laws book.',
 '03. BY COLLECTION/01. ROOTS · Principles · R&D · IP', 9),

('library_type', 'R&D Entry',
 'Research finding or experiment. Lives in Roots / R&D book.',
 '03. BY COLLECTION/01. ROOTS · Principles · R&D · IP', 10),

('library_type', 'Knowledge Piece',
 'Structured piece of learning from Deep Reader or any seat.',
 '03. BY COLLECTION/01. ROOTS · Principles · R&D · IP', 11),

('library_type', 'IP DOI Entry',
 'Zenodo upload or IP registration record. Immutable from creation. Doctor M keeper.',
 '02. BY TYPE/08. PUBLICATIONS · DOI', 12),

('library_type', 'Paper',
 'Academic paper or publication. Lives in Academic Branch book.',
 '02. BY TYPE/08. PUBLICATIONS · DOI', 13),

('library_type', 'Application',
 'Formal application document. For YC, grants, programmes. Wolf reviews legal terms.',
 '03. BY COLLECTION/02. TRUNK · Strategy', 14),

('library_type', 'Contract',
 'Legal agreement document. Lives in Legal book. Wolf keeper. Immutable after signature.',
 '02. BY TYPE/07. CONTRACTS', 15),

('library_type', 'Legal Definition',
 'Defined legal term or position. Lives in Legal book. Wolf keeper.',
 '02. BY TYPE/06. LEGAL RECORDS', 16),

('library_type', 'Financial Ledger',
 'Financial record or statement. Lives in Finance book. Freya and Mercury keepers.',
 '03. BY COLLECTION/04. TRUNK · Finance', 17),

('library_type', 'Governance Entry',
 'Governance decision record. Lives in Governance book. Bard keeper.',
 '03. BY COLLECTION/05. TRUNK · Governance', 18),

('library_type', 'System Prompt',
 'Agent identity document. Lives in Persistent Memory book. Il Maestro keeper.',
 '03. BY COLLECTION/06. TRUNK · Persistent Memory', 19),

('library_type', 'Rule of Engagement',
 'Operational rule for a seat. Lives in Persistent Memory book. Il Maestro keeper.',
 '03. BY COLLECTION/06. TRUNK · Persistent Memory', 20),

('library_type', 'Agentic Architecture',
 'Technical governance document. Lives in Persistent Memory book.',
 '03. BY COLLECTION/06. TRUNK · Persistent Memory', 21),

('library_type', 'Narrative',
 'Company story or cultural record. Cross-domain. DOI-able via Zenodo. Frankie Master keeper.',
 '02. BY TYPE/05. NARRATIVES', 22),

('library_type', 'Post',
 'Content publication. Social post, field note, article. Lives in Narrative book.',
 '02. BY TYPE/12. CONTENT · Posts', 23),

('library_type', 'Voice Definition',
 'Frankie''s voice system document. Collaboration note, calibration examples, CTA rotation, sign-off rotation.',
 '01. BY SEAT/06. FRANKIE · Narrative', 24),

('library_type', 'Product Bible',
 'Product principles and vision. Lives in Ventura Branch book.',
 '03. BY COLLECTION/09. BRANCH · Ventura · Product', 25),

('library_type', 'Product Definition',
 'Specific product specification. Lives in Ventura Branch book.',
 '03. BY COLLECTION/09. BRANCH · Ventura · Product', 26),

('library_type', 'Product Rule',
 'Product governance rule. Lives in Ventura Branch book.',
 '03. BY COLLECTION/09. BRANCH · Ventura · Product', 27),

('library_type', 'Strategy Definition',
 'Strategic direction document. Lives in Strategy book. Freya keeper.',
 '03. BY COLLECTION/02. TRUNK · Strategy', 28),

('library_type', 'Proposal',
 'Formal proposal document. For clients, partners, investors.',
 '02. BY TYPE/13. PROPOSALS', 29),

('library_type', 'Presentation',
 'Slide deck or visual presentation.',
 '02. BY TYPE/09. PRESENTATIONS', 30),

('library_type', 'Other',
 'Does not fit any of the above types. Flag for Il Maestro to review.',
 '01. BY SEAT', 31);

-- ================================================
-- SECTION C — STATUS VALUES
-- vocab_type = 'fm_status' and 'library_status'
-- ================================================
INSERT INTO maestro_vocabulary (vocab_type, name, definition, display_order) VALUES

('fm_status', 'To Do',         'Not yet started.',                         1),
('fm_status', 'Agent Draft',   'Seat is working on this.',                 2),
('fm_status', 'Agent Action',  'Seat is executing an action.',             3),
('fm_status', 'Review',        'Ready for V or keeper review.',            4),
('fm_status', 'Doing',         'Actively in progress.',                    5),
('fm_status', 'Done',          'Complete. Immutable.',                     6),
('fm_status', 'Deferred',      'Postponed. Has a reason. Will return.',    7),
('fm_status', 'Cancelled',     'Will not happen. Record remains.',         8),

('library_status', 'To Create',  'Stub exists. Content not yet written.',  1),
('library_status', 'Agent Draft','Seat is writing the document.',          2),
('library_status', 'Created',    'Document written. Not yet reviewed.',    3),
('library_status', 'Reviewed',   'Reviewed by keeper. Awaiting V seal.',   4),
('library_status', 'V Sealed',   'V has sealed. Immutable.',               5),

('gate_status', 'N/A',       'Not applicable to this row.',                1),
('gate_status', 'To Clear',  'Gate is open. Keeper must review.',          2),
('gate_status', 'Cleared',   'Gate cleared by keeper. Record exists.',     3),

('priority', 'Urgent',       'Drop everything. Fires immediately.',        1),
('priority', 'Important',    'This week. Do not let it slip.',             2),
('priority', 'Regular',      'Standard cadence. This sprint.',             3),
('priority', 'Low',          'When capacity allows.',                      4),
('priority', 'Nice to have', 'Deferred until foundation is stable.',       5),

('one_ko', 'To Do',        'Not yet submitted.',                           1),
('one_ko', 'Auto Apply',   'Mercury submits without V review.',            2),
('one_ko', 'Review',       'Needs V review before submission.',            3),
('one_ko', 'Applied',      'Submitted. Awaiting response.',                4),
('one_ko', 'Success',      'Accepted. A win counted toward 1000.',         5),
('one_ko', 'Learning',     'Rejected. Learning captured.',                 6),
('one_ko', 'Expired',      'Deadline passed without submission.',          7);
