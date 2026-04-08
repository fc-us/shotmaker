#!/bin/bash
# Export ShotMaker screenshots to Obsidian-compatible markdown notes
# Usage: ./export-to-obsidian.sh [output-dir]

DB="$HOME/Library/Application Support/ShotMaker/screenshots.db"
OUT_DIR="${1:-$HOME/Documents/Claude/screenotate/export}"

mkdir -p "$OUT_DIR"

count=0
sqlite3 "$DB" -separator '|||' "SELECT id, file_path, ocr_text, tag, app_name, datetime(created_at, 'unixepoch', 'localtime') FROM screenshots ORDER BY created_at DESC;" | while IFS='|||' read -r id file_path ocr_text tag app_name created_at; do
    # Create filename from timestamp
    safe_date=$(echo "$created_at" | tr ' :' '-_')
    filename="screenshot-${safe_date}.md"

    cat > "$OUT_DIR/$filename" << EOF
---
type: screenshot
tag: ${tag}
app: ${app_name}
captured: ${created_at}
source: ${file_path}
---

# Screenshot — ${created_at}

**App:** ${app_name}
**Tag:** ${tag}
**File:** \`$(basename "$file_path")\`

## Extracted Text

${ocr_text}
EOF
    count=$((count + 1))
done

echo "Exported to $OUT_DIR"
ls "$OUT_DIR" | wc -l | xargs echo "Files created:"
