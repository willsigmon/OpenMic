#!/bin/bash
# Deploy Supabase backend for OpenMic
# Prerequisites: npm install -g supabase

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== OpenMic Supabase Deployment ==="
echo ""

# Check supabase CLI
if ! command -v supabase &> /dev/null; then
    echo "Error: supabase CLI not found. Install with: brew install supabase/tap/supabase"
    exit 1
fi

cd "$PROJECT_DIR"

# Step 1: Link project (interactive — will prompt for project ref)
echo "Step 1: Link to Supabase project"
echo "  If not linked yet, run: supabase link --project-ref <your-project-ref>"
echo ""

# Step 2: Apply migrations
echo "Step 2: Applying database migrations..."
supabase db push
echo "  Migrations applied."
echo ""

# Step 3: Deploy Edge Functions
echo "Step 3: Deploying Edge Functions..."

echo "  Deploying realtime-proxy..."
supabase functions deploy realtime-proxy --no-verify-jwt

echo "  Deploying verify-receipt..."
supabase functions deploy verify-receipt --no-verify-jwt

echo "  Edge Functions deployed."
echo ""

# Step 4: Set secrets for Edge Functions
echo "Step 4: Setting Edge Function secrets..."
echo "  You need to set these secrets manually:"
echo "    supabase secrets set OPENAI_API_KEY=sk-..."
echo "    supabase secrets set GEMINI_API_KEY=..."
echo "    supabase secrets set HUME_API_KEY=..."
echo "    supabase secrets set ELEVENLABS_API_KEY=..."
echo "    supabase secrets set APP_STORE_SHARED_SECRET=..."
echo ""

# Step 5: Get project URL and anon key
echo "Step 5: Project credentials"
echo "  Get these from your Supabase dashboard → Settings → API:"
echo "  - Project URL: https://<ref>.supabase.co"
echo "  - Anon Key: eyJ..."
echo ""
echo "  Then update OpenMic/Services/Auth/SupabaseClient.swift"
echo "  or set SUPABASE_URL and SUPABASE_ANON_KEY in Info.plist / xcconfig."
echo ""

echo "=== Deployment complete ==="
