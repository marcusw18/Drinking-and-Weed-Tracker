#!/bin/bash
# Reads .env.local and generates DrinkingTracker/Secrets.swift
# Usage: ./scripts/apply_env.sh [path/to/env/file]
set -euo pipefail

ENV_FILE="${1:-.env.local}"
OUTPUT="DrinkingTracker/Secrets.swift"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌  $ENV_FILE not found."
    echo "    Copy .env.example to .env.local and fill in your API keys:"
    echo "    cp .env.example .env.local"
    exit 1
fi

# Parse key=value pairs (skip comments and blank lines)
declare -A vars
while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    key=$(echo "$key" | tr -d '[:space:]')
    vars["$key"]="$value"
done < "$ENV_FILE"

SUPABASE_URL="${vars[SUPABASE_URL]:-}"
SUPABASE_ANON_KEY="${vars[SUPABASE_ANON_KEY]:-}"
GEMINI_API_KEY="${vars[GEMINI_API_KEY]:-}"
VULTURE_SERVER_URL="${vars[VULTURE_SERVER_URL]:-http://localhost:8000}"
SMART_SPECTRA_API_KEY="${vars[SMART_SPECTRA_API_KEY]:-}"

cat > "$OUTPUT" << SWIFT
// AUTO-GENERATED — do not commit this file.
// Regenerate by running: ./scripts/apply_env.sh
enum Secrets {
    static let supabaseURL          = "${SUPABASE_URL}"
    static let supabaseAnonKey      = "${SUPABASE_ANON_KEY}"
    static let geminiAPIKey         = "${GEMINI_API_KEY}"
    static let vultureServerURL     = "${VULTURE_SERVER_URL}"
    static let smartSpectraAPIKey   = "${SMART_SPECTRA_API_KEY}"
}
SWIFT

echo "✅  Secrets.swift generated from $ENV_FILE"
