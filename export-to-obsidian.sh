#!/bin/bash
# Export ShotMaker screenshots to Obsidian-compatible markdown notes
# Usage: ./export-to-obsidian.sh [output-dir]

DB="$HOME/Library/Application Support/ShotMaker/screenshots.db"
OUT_DIR="${1:-$HOME/Documents/ShotMaker/export}"

mkdir -p "$OUT_DIR"

sqlite3 "$DB" -json "SELECT id, file_path, ocr_text, tag, app_name, datetime(created_at, 'unixepoch', 'localtime') AS created_at FROM screenshots ORDER BY created_at DESC;" | \
python3 -c "
import json, sys, os, re

data = json.load(sys.stdin)
out_dir = sys.argv[1]
count = 0

for row in data:
    created_at = row.get('created_at', '')
    row_id = row.get('id', 0)
    safe_date = re.sub(r'[ :]', '-', created_at)
    filename = f'screenshot-{safe_date}-{row_id}.md'
    filepath = os.path.join(out_dir, filename)

    tag = row.get('tag') or ''
    app_name = row.get('app_name') or ''
    file_path = row.get('file_path') or ''
    ocr_text = row.get('ocr_text') or ''
    base = os.path.basename(file_path)

    content = f'''---
type: screenshot
tag: \"{tag}\"
app: \"{app_name}\"
captured: \"{created_at}\"
source: \"{file_path}\"
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
    count += 1

print(f'Exported {count} notes to {out_dir}')
" "$OUT_DIR"
