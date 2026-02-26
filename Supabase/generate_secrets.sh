#!/bin/bash
# Generates Secrets.generated.swift from Secrets.xcconfig
# Run during Xcode build to inject credentials without hardcoding.
# (Xcode uses an inline copy of this script; this file is for reference.)

CONFIG_FILE="${SRCROOT}/Supabase/Secrets.xcconfig"
OUTPUT_FILE="${SRCROOT}/GreatResetFantasy/Generated/Secrets.generated.swift"

mkdir -p "$(dirname "$OUTPUT_FILE")"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "error: Supabase/Secrets.xcconfig not found. Copy docs/Supabase_credentials_setup.xcconfig to Supabase/Secrets.xcconfig and add your credentials."
  exit 1
fi

# Parse xcconfig: get value after = for each key (trim whitespace with sed)
SUPABASE_URL=$(grep "^SUPABASE_URL" "$CONFIG_FILE" | cut -d= -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
SUPABASE_KEY=$(grep "^SUPABASE_KEY" "$CONFIG_FILE" | cut -d= -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_KEY" ]; then
  echo "error: SUPABASE_URL and SUPABASE_KEY must be set in Secrets.xcconfig"
  exit 1
fi

# Escape backslashes and quotes for Swift string literals
SUPABASE_URL_ESC="${SUPABASE_URL//\\/\\\\}"
SUPABASE_URL_ESC="${SUPABASE_URL_ESC//\"/\\\"}"
SUPABASE_KEY_ESC="${SUPABASE_KEY//\\/\\\\}"
SUPABASE_KEY_ESC="${SUPABASE_KEY_ESC//\"/\\\"}"

cat > "$OUTPUT_FILE" << EOF
// Auto-generated from Secrets.xcconfig — do not edit
enum Secrets {
    static let supabaseURL = "$SUPABASE_URL_ESC"
    static let supabaseKey = "$SUPABASE_KEY_ESC"
}
EOF
