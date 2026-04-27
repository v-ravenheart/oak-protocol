// OAK PROTOCOL · Canary: SEQUOIA14APRIL
// Deployed: 27 April 2026
// OKKA Expanded Intelligence OÜ
// appscript/document-mirror.gs
//
// Google Apps Script — deployed as a web app.
// Runs in: V's Google account (its.v@okka.ai)
// Execute as: Me (its.v@okka.ai)
// Who has access: Anyone with the link (verified by shared secret)
//
// Called by: Supabase Edge Function after forest_library INSERT
// Action: Creates a Google Doc in the correct Drive folder,
//         creates shortcuts in BY TYPE and BY COLLECTION folders,
//         returns the Drive document URL.
//
// Setup:
//   1. Deploy as web app in Google Apps Script
//   2. Copy the deployment URL
//   3. Add to V's Supabase vault as: APPSCRIPT_DOCUMENT_MIRROR_URL
//   4. Add a shared secret to vault as: APPSCRIPT_SHARED_SECRET
//   5. Set the same secret as scriptProperty APPSCRIPT_SHARED_SECRET

// ================================================
// DRIVE FOLDER STRUCTURE
// Root: [00. MASTER OKKA]
// Set MASTER_FOLDER_ID in Script Properties to the
// folder ID of [00. MASTER OKKA] in V's Drive.
// ================================================

// Map: document_type → path segment under 02. BY TYPE
const TYPE_FOLDER_MAP = {
  'Chronicle':           '01. CHRONICLES',
  'Working Document':    '02. WORKING DOCUMENTS',
  'First Page':          '03. BOOKS · First Pages',
  'Roundtable':          '04. ROUNDTABLES',
  'Roundtable Verse':    '04. ROUNDTABLES',
  'Narrative':           '05. NARRATIVES',
  'Legal Record':        '06. LEGAL RECORDS',
  'Contract':            '07. CONTRACTS',
  'Publication Record':  '08. PUBLICATIONS · DOI',
  'IP DOI Entry':        '08. PUBLICATIONS · DOI',
  'Paper':               '08. PUBLICATIONS · DOI',
  'Presentation':        '09. PRESENTATIONS',
  'System Prompt':       '10. SYSTEM PROMPTS · Rules of Engagement',
  'Rule of Engagement':  '10. SYSTEM PROMPTS · Rules of Engagement',
  'Financial Ledger':    '11. FINANCIAL RECORDS',
  'Post':                '12. CONTENT · Posts',
  'Proposal':            '13. PROPOSALS',
}

// Map: document seat (author[0]) → path segment under 01. BY SEAT
const SEAT_FOLDER_MAP = {
  'v':               '00. V · Board',
  'bard':            '01. BARD · Governance',
  'maestro':         '02. MAESTRO · Persistent Memory',
  'mercury':         '03. MERCURY · Operations',
  'freya':           '04. FREYA · Strategy',
  'wolf':            '05. WOLF · Legal',
  'frankie':         '06. FRANKIE · Narrative',
  'frankie-c':       '07. FRANKIE-C · Content',
  'frankie-b':       '08. FRANKIE-B · Branding',
  'deep-r':          '09. DEEP-R · R&D Reading',
  'ip-keeper':       '10. IP-KEEPER · IP Registry',
  'ventura':         '11. VENTURA · Product',
  'serena':          '12. SERENA · AMI',
  'doctor-m':        '13. DOCTOR-M · Academic',
}

// Map: collections value → path segment under 03. BY COLLECTION
const COLLECTION_FOLDER_MAP = {
  'Roots':         '01. ROOTS · Principles · R&D · IP',
  'Trunk':         '02. TRUNK · Strategy',   // default trunk; see books below
  'Roundtable':    '00. ALL FOREST · Organism Level',
  'Magna Carta':   '13. MAGNA CARTA · Constitutional',
}

// Map: books value → specific trunk collection folder
const BOOKS_COLLECTION_MAP = {
  'Strategy':                          '02. TRUNK · Strategy',
  'Legal':                             '03. TRUNK · Legal',
  'Finance':                           '04. TRUNK · Finance',
  'Governance':                        '05. TRUNK · Governance',
  'Persistent Memory and Agentic Gov': '06. TRUNK · Persistent Memory',
  'Narrative':                         '07. TRUNK · Narrative',
  'Operations':                        '08. TRUNK · Operations',
  'Ventura':                           '09. BRANCH · Ventura · Product',
  'AMI':                               '10. BRANCH · AMI',
  'Academic':                          '11. BRANCH · Academic',
  'Commercial':                        '12. BRANCH · Commercial',
}

/**
 * Get or create a folder by name within a parent folder.
 */
function getOrCreateFolder(parent, name) {
  const existing = parent.getFoldersByName(name)
  if (existing.hasNext()) return existing.next()
  return parent.createFolder(name)
}

/**
 * Get master folder by ID from Script Properties.
 */
function getMasterFolder() {
  const folderId = PropertiesService.getScriptProperties()
    .getProperty('MASTER_FOLDER_ID')
  if (!folderId) throw new Error('MASTER_FOLDER_ID not set in Script Properties.')
  return DriveApp.getFolderById(folderId)
}

/**
 * Determine the primary BY SEAT folder for a document.
 */
function getSeatFolder(masterFolder, authorSlug) {
  const seatName = SEAT_FOLDER_MAP[authorSlug] ?? '00. V · Board'
  const bySeats = getOrCreateFolder(masterFolder, '01. BY SEAT')
  return getOrCreateFolder(bySeats, seatName)
}

/**
 * Determine the BY TYPE folder for a document.
 */
function getTypeFolder(masterFolder, documentType) {
  const typeName = TYPE_FOLDER_MAP[documentType] ?? '01. CHRONICLES'
  const byType = getOrCreateFolder(masterFolder, '02. BY TYPE')
  return getOrCreateFolder(byType, typeName)
}

/**
 * Determine the BY COLLECTION folder for a document.
 */
function getCollectionFolder(masterFolder, collections, books) {
  const byCollection = getOrCreateFolder(masterFolder, '03. BY COLLECTION')

  // Try books mapping first (more specific)
  if (books && books.length > 0) {
    const bookFolder = BOOKS_COLLECTION_MAP[books[0]]
    if (bookFolder) return getOrCreateFolder(byCollection, bookFolder)
  }

  // Fall back to collections mapping
  if (collections && collections.length > 0) {
    const collFolder = COLLECTION_FOLDER_MAP[collections[0]]
    if (collFolder) return getOrCreateFolder(byCollection, collFolder)
  }

  // Default: All Forest
  return getOrCreateFolder(byCollection, '00. ALL FOREST · Organism Level')
}

/**
 * Create the document header with FM UUID and Library UUID.
 * Every OAK document carries both IDs. Always traceable.
 */
function buildDocumentHeader(payload) {
  const lines = [
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    `OAK PROTOCOL · ${payload.document_type ?? 'Document'}`,
    `Title: ${payload.document_title}`,
    `Author: ${(payload.author ?? ['v']).join(', ')}`,
    `Date: ${payload.date ?? new Date().toISOString().split('T')[0]}`,
    `Canary: ${payload.canary ?? 'SEQUOIA14APRIL'}`,
    payload.fm_row_id   ? `Forest Master UUID: ${payload.fm_row_id}` : null,
    payload.library_id  ? `Forest Library UUID: ${payload.library_id}` : null,
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
    '',
  ].filter(Boolean)

  return lines.join('\n')
}

/**
 * Main doPost handler.
 * Called by Supabase Edge Function after forest_library INSERT.
 */
function doPost(e) {
  try {
    // Validate shared secret
    const authHeader = e.parameter.authorization
      || (e.postData?.contents
          ? JSON.parse(e.postData.contents).authorization
          : null)

    const expectedSecret = PropertiesService.getScriptProperties()
      .getProperty('APPSCRIPT_SHARED_SECRET')

    if (!expectedSecret || authHeader !== 'Bearer ' + expectedSecret) {
      return ContentService
        .createTextOutput(JSON.stringify({ error: 'Unauthorized.' }))
        .setMimeType(ContentService.MimeType.JSON)
    }

    // Parse payload
    const payload = JSON.parse(e.postData.contents)
    const {
      document_type,
      document_title,
      full_document,
      author,
      date,
      canary,
      library_id,
      fm_row_id,
      collections,
      books,
    } = payload

    if (!document_title || !full_document) {
      throw new Error('document_title and full_document are required.')
    }

    const masterFolder = getMasterFolder()
    const authorSlug   = (author && author.length > 0) ? author[0] : 'v'

    // Primary location: BY SEAT
    const seatFolder   = getSeatFolder(masterFolder, authorSlug)

    // Build document content
    const header  = buildDocumentHeader(payload)
    const content = header + '\n' + full_document

    // Create Google Doc in BY SEAT folder
    const doc = DocumentApp.create(document_title)
    const docFile = DriveApp.getFileById(doc.getId())
    seatFolder.addFile(docFile)
    DriveApp.getRootFolder().removeFile(docFile) // Remove from root

    // Write content to doc
    const body = doc.getBody()
    body.clear()

    // Header in a distinct paragraph style
    const headerPara = body.appendParagraph(
      `OAK PROTOCOL · ${document_type ?? 'Document'}`
    )
    headerPara.setHeading(DocumentApp.ParagraphHeading.HEADING1)

    body.appendParagraph(`Title: ${document_title}`)
    body.appendParagraph(`Author: ${(author ?? ['v']).join(', ')}`)
    body.appendParagraph(`Date: ${date ?? new Date().toISOString().split('T')[0]}`)
    body.appendParagraph(`Canary: ${canary ?? 'SEQUOIA14APRIL'}`)
    if (fm_row_id)  body.appendParagraph(`Forest Master UUID: ${fm_row_id}`)
    if (library_id) body.appendParagraph(`Forest Library UUID: ${library_id}`)
    body.appendHorizontalRule()
    body.appendParagraph(full_document)

    doc.saveAndClose()

    const driveUrl = docFile.getUrl()

    // Shortcut 1: BY TYPE
    try {
      const typeFolder = getTypeFolder(masterFolder, document_type)
      typeFolder.createShortcut(docFile.getId())
    } catch (e) {
      Logger.log('BY TYPE shortcut failed: ' + e)
    }

    // Shortcut 2: BY COLLECTION
    try {
      const collFolder = getCollectionFolder(masterFolder, collections, books)
      collFolder.createShortcut(docFile.getId())
    } catch (e) {
      Logger.log('BY COLLECTION shortcut failed: ' + e)
    }

    // Return Drive URL to Edge Function for writing back to forest_library
    return ContentService
      .createTextOutput(JSON.stringify({
        status:    'created',
        drive_url: driveUrl,
        doc_id:    doc.getId(),
      }))
      .setMimeType(ContentService.MimeType.JSON)

  } catch (err) {
    Logger.log('doPost error: ' + err)
    return ContentService
      .createTextOutput(JSON.stringify({
        error:  'Document creation failed.',
        detail: String(err),
      }))
      .setMimeType(ContentService.MimeType.JSON)
  }
}

/**
 * doGet — health check endpoint.
 * Returns canary confirmation so Cowork can verify deployment.
 */
function doGet() {
  return ContentService
    .createTextOutput(JSON.stringify({
      status: 'ok',
      canary: 'SEQUOIA14APRIL',
      service: 'OAK Protocol · Document Mirror',
    }))
    .setMimeType(ContentService.MimeType.JSON)
}
