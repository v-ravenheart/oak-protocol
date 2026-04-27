// OAK PROTOCOL · Canary: SEQUOIA14APRIL
// Deployed: 27 April 2026
// OKKA Expanded Intelligence OÜ
// edge-functions/calendar-sync/index.ts
//
// Bidirectional Google Calendar sync.
// Direction 1 (FM → Calendar): FM row with forest_roadmap=TRUE or
//   Type=Meeting or Milestone → creates Google Calendar event.
// Direction 2 (Calendar → FM): Called by Calendar webhook or
//   scheduled poll → creates FM row for new calendar events.
//
// Auth: OAuth refresh token pattern (agreed RT-002 Question A).
// Secrets required (set in V's Supabase vault):
//   GOOGLE_OAUTH_CLIENT_ID
//   GOOGLE_OAUTH_CLIENT_SECRET
//   GOOGLE_CALENDAR_REFRESH_TOKEN
//
// On calendar_auth_failure: logs to alerts table and returns 502.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'
const GOOGLE_CALENDAR_API = 'https://www.googleapis.com/calendar/v3'

// Fetch a fresh Google access token using the stored refresh token.
// Refresh tokens do not expire under normal use (RT-002 confirmed).
async function getGoogleAccessToken(): Promise<string> {
  const clientId     = Deno.env.get('GOOGLE_OAUTH_CLIENT_ID') ?? ''
  const clientSecret = Deno.env.get('GOOGLE_OAUTH_CLIENT_SECRET') ?? ''
  const refreshToken = Deno.env.get('GOOGLE_CALENDAR_REFRESH_TOKEN') ?? ''

  if (!clientId || !clientSecret || !refreshToken) {
    throw new Error('calendar_auth_failure: Missing Google OAuth credentials in Supabase vault.')
  }

  const res = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id:     clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type:    'refresh_token',
    }),
  })

  if (!res.ok) {
    const err = await res.text()
    throw new Error(`calendar_auth_failure: Token refresh failed — ${err}`)
  }

  const json = await res.json()
  if (!json.access_token) {
    throw new Error('calendar_auth_failure: No access_token in token response.')
  }

  return json.access_token
}

// Create a Google Calendar event from an FM row.
async function createCalendarEvent(
  accessToken: string,
  calendarId: string,
  fm: {
    id: string
    title: string
    description?: string
    deadline?: string
    prep_date?: string
    fm_type?: string
  }
): Promise<string> {
  // Determine event date — prefer deadline, fall back to prep_date
  const eventDate = fm.deadline ?? fm.prep_date
  if (!eventDate) {
    throw new Error('Cannot create calendar event: no deadline or prep_date on FM row.')
  }

  const event = {
    summary:     fm.title,
    description: [
      fm.description ?? '',
      '',
      `OAK Protocol FM Row: ${fm.id}`,
      `Type: ${fm.fm_type ?? 'Entry'}`,
    ].join('\n').trim(),
    start: { date: eventDate },
    end:   { date: eventDate },
    extendedProperties: {
      private: {
        oak_fm_id:   fm.id,
        oak_fm_type: fm.fm_type ?? '',
        oak_canary:  'SEQUOIA14APRIL',
      },
    },
  }

  const res = await fetch(
    `${GOOGLE_CALENDAR_API}/calendars/${encodeURIComponent(calendarId)}/events`,
    {
      method: 'POST',
      headers: {
        Authorization:  `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(event),
    }
  )

  if (!res.ok) {
    const err = await res.text()
    throw new Error(`Calendar event creation failed: ${err}`)
  }

  const created = await res.json()
  return created.id as string
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'POST only.' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  // Initialize service role client for alert logging
  const serviceClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    { auth: { persistSession: false } }
  )

  try {
    const body = await req.json()
    const { direction, fm_row, calendar_id } = body

    // direction: 'fm_to_calendar' or 'calendar_to_fm'
    if (!direction) {
      return new Response(
        JSON.stringify({ error: 'direction is required: fm_to_calendar or calendar_to_fm' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get fresh access token — one HTTP round trip per call
    let accessToken: string
    try {
      accessToken = await getGoogleAccessToken()
    } catch (authErr) {
      const msg = String(authErr)

      // Log auth failure to alerts table — surfaces in Forest Wake-Up
      await serviceClient.from('alerts').insert({
        event_type: 'calendar_auth_failure',
        event_desc: msg,
        seat_target: 'mercury',
      })

      return new Response(
        JSON.stringify({ error: msg }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (direction === 'fm_to_calendar') {
      // Validate required fields
      if (!fm_row?.id || !calendar_id) {
        return new Response(
          JSON.stringify({ error: 'fm_row.id and calendar_id are required for fm_to_calendar.' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const eventId = await createCalendarEvent(accessToken, calendar_id, fm_row)

      return new Response(
        JSON.stringify({ status: 'created', calendar_event_id: eventId }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (direction === 'calendar_to_fm') {
      // Payload from Calendar MCP or webhook: new event data
      const { event } = body
      if (!event?.summary) {
        return new Response(
          JSON.stringify({ error: 'event.summary is required for calendar_to_fm.' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Check if this event already has an OAK FM row (avoid duplicate)
      const existingFmId = event.extendedProperties?.private?.oak_fm_id
      if (existingFmId) {
        return new Response(
          JSON.stringify({ status: 'skipped', reason: 'OAK FM row already exists for this event.', fm_id: existingFmId }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      // Determine FM type from calendar
      const fmType = calendar_id?.includes('roadmap') ? 'Milestone' : 'Meeting'
      const eventDate = event.start?.date ?? event.start?.dateTime?.split('T')[0]

      const { data: newRow, error: insertErr } = await serviceClient
        .from('forest_master')
        .insert({
          title:          event.summary,
          fm_type:        fmType,
          description:    event.description ?? '',
          date:           eventDate,
          deadline:       eventDate,
          status:         'To Do',
          inserted_by:    'calendar-sync',
          system_created: TRUE,
          canary:         'SEQUOIA14APRIL',
          is_action:      TRUE,
        })
        .select('id')
        .single()

      if (insertErr) {
        throw new Error(`FM insert failed: ${insertErr.message}`)
      }

      return new Response(
        JSON.stringify({ status: 'created', fm_id: newRow?.id }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ error: 'Unknown direction. Use fm_to_calendar or calendar_to_fm.' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    console.error('calendar-sync error:', err)

    await serviceClient.from('alerts').insert({
      event_type: 'Edge Function Failure',
      event_desc: `calendar-sync failed: ${String(err)}`,
      seat_target: 'mercury',
    })

    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
