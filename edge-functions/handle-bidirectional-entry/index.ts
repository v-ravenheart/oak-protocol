// OAK PROTOCOL · Canary: SEQUOIA14APRIL
// Deployed: 27 April 2026
// OKKA Expanded Intelligence OÜ
// edge-functions/handle-bidirectional-entry/index.ts
//
// HTTP interface for the bidirectional entry stored procedure.
// Called by: Serena UI · Telegram bot · Calendar sync · Seat browser chats
// Calls: forest_handle_bidirectional_entry() via Supabase RPC
//
// Request body:
//   source_table: 'forest_master' | 'forest_library'
//   source_id:    UUID of the newly inserted row
//   entry_type:   FM type or Library row_type string
//   seat_slug:    Who is calling (defaults to 'v')
//
// Response: JSONB from the stored procedure

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed. POST only.' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  try {
    // Auth: require Bearer token (service role or user JWT)
    const authHeader = req.headers.get('Authorization')
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ error: 'Missing or invalid Authorization header.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const body = await req.json()
    const { source_table, source_id, entry_type, seat_slug } = body

    // Validate required fields
    if (!source_table || !source_id) {
      return new Response(
        JSON.stringify({ error: 'source_table and source_id are required.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!['forest_master', 'forest_library'].includes(source_table)) {
      return new Response(
        JSON.stringify({ error: 'source_table must be forest_master or forest_library.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Validate UUID format
    const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    if (!uuidPattern.test(source_id)) {
      return new Response(
        JSON.stringify({ error: 'source_id must be a valid UUID.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Initialize Supabase client with the caller's token
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: { headers: { Authorization: authHeader } },
        auth: { persistSession: false },
      }
    )

    // Call the stored procedure — atomic transaction guaranteed
    const { data, error } = await supabaseClient.rpc(
      'forest_handle_bidirectional_entry',
      {
        p_source_table: source_table,
        p_source_id:    source_id,
        p_entry_type:   entry_type ?? '',
        p_seat_slug:    seat_slug ?? 'v',
      }
    )

    if (error) {
      console.error('RPC error:', error)

      // Log failure to alerts via service role (procedure may have already done this)
      const serviceClient = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
        { auth: { persistSession: false } }
      )

      await serviceClient.from('alerts').insert({
        event_type: 'Edge Function Failure',
        event_desc: `handle-bidirectional-entry failed · ${error.message}`,
      })

      return new Response(
        JSON.stringify({ error: error.message, detail: error.details }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify(data),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    console.error('Unexpected error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error', detail: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
