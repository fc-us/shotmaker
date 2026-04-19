#!/bin/bash
# Export ShotMaker screenshots to Obsidian-compatible markdown notes
# Usage: ./export-to-obsidian.sh [output-dir]

DB="$HOME/Library/Application Support/ShotMaker/screenshots.db"
OUT_DIR="${1:-$HOME/Documents/ShotMaker/export}"

mkdir -p "$OUT_DIR"

count=0
sqlite3 "$DB" -json "SELECT id, file_path, ocr_text, tag, app_name, datetime(created_at, 'unixepoch', 'localtime') AS created_at FROM screenshots ORDER BY created_at DESC;" | \
python3 -c "
import json, sys, os, re

data = json.load(sys.stdin)
out_dir = sys.argv[1]

for row in data:
    created_at = row.get('created_at', '')
    safe_date = re.sub(r'[ :]', '-', created_at).replace('--', '-')
    filename = f'screenshot-{safe_date}.md'
    filepath = os.path.join(out_dir, filename)

    tag = row.get('tag', '')
    app_name = row.get('app_name', '')
    file_path = row.get('file_path', '')
    ocr_text = row.get('ocr_text', '')
    base = os.path.basename(file_path)

    content = f'''---
type: screenshot
tag: {tag}
app: {app_name}
captured: {created_at}
source: {file_path}
---

# Screenshot — {created_at}

**App:** {app_name}
**Tag:** {tag}
**File:** \`{base}\`

## Extracted Text

{ocr_text}
'''
    with open(filepath, 'w') as f:
        f.write(content)
    print(f'wrote {filename}')
" "$OUT_DIR"

echo "Exported to $OUT_DIR"
