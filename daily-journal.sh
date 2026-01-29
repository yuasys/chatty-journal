#!/bin/zsh

# ---------------------------------------------------------
# Daily Journal Automation Script
# ---------------------------------------------------------

# 1. 基本情報
REPO_ROOT="/Users/yuasys/source/chatty-journal"
URL_BASE="https://github.com/yuasys/chatty-journal/blob/main"

# 移動
if [[ -d "$REPO_ROOT" ]]; then
    cd "$REPO_ROOT" || { echo "Failed to enter $REPO_ROOT"; exit 1; }
else
    echo "Repository directory not found: $REPO_ROOT"
    exit 1
fi

# 2. 日付計算
# 最新の日誌ファイルを検索して、その翌日を「今日」とする
# Find all journal files: YYYY/MM/YYYY-MM-DD.md
# Search depth 3 (./YYYY/MM/file.md)
LATEST_FILE=$(find . -maxdepth 3 -type f -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md" | sort | tail -1)

if [[ -n "$LATEST_FILE" ]]; then
    LATEST_DATE=$(basename "$LATEST_FILE" .md)
    # TODAY is Latest + 1 day
    TODAY_YMD=$(date -j -v+1d -f "%Y-%m-%d" "$LATEST_DATE" "+%Y-%m-%d")
    echo "Found latest entry: $LATEST_DATE. Creating entry for: $TODAY_YMD"
else
    # Failure fallback: use real today
    TODAY_YMD=$(date +%Y-%m-%d)
    echo "No existing entries found. Creating entry for today: $TODAY_YMD"
fi

TODAY_YEAR=${TODAY_YMD:0:4}
TODAY_MONTH=${TODAY_YMD:5:2}

# Header Date: e.g., 2026年01月17日（土）
# Force Japanese Locale for this command, parse calculated TODAY_YMD
HEADER_DATE=$(LC_TIME=ja_JP.UTF-8 date -j -f "%Y-%m-%d" "$TODAY_YMD" "+%Y年%m月%d日（%a）")

# Previous/Next Day (Calculated from TODAY_YMD)
YESTERDAY_YMD=$(date -j -v-1d -f "%Y-%m-%d" "$TODAY_YMD" "+%Y-%m-%d")
TOMORROW_YMD=$(date -j -v+1d -f "%Y-%m-%d" "$TODAY_YMD" "+%Y-%m-%d")

# Generate Paths for Links
PREV_DAY_LINK="${URL_BASE}/${YESTERDAY_YMD:0:4}/${YESTERDAY_YMD:5:2}/${YESTERDAY_YMD}.md"
NEXT_DAY_LINK="${URL_BASE}/${TOMORROW_YMD:0:4}/${TOMORROW_YMD:5:2}/${TOMORROW_YMD}.md"

# 3. 前の記事 (Existing latest journal) logic
# Ref: Logic imported from find_latest_valid_journal.sh to ensure we link to a valid post
setopt extended_glob

# Search for potential files (recursive) checking date >= 2025-04-08 (from find_latest_valid_journal.sh logic)
# We want files *before* the TODAY_YMD we are about to create.
matched_files=()
MIN_DATE_FILE="2025-04-08.md"

# Find files recursively
# Note: In the original script we're at REPO_ROOT.
# We iterate over all md files matching convention.
for file in ./**/[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].md(N); do
    filename=$(basename "$file")
    
    # Must be >= MIN_DATE_FILE
    [[ "$filename" < "$MIN_DATE_FILE" ]] && continue

    # Must be < TODAY_YMD (strictly previous)
    [[ "$filename" < "${TODAY_YMD}.md" ]] || continue
    
    # Check for content validity (3 dashes, content between 2nd and 3rd dash)
    dash_lines=($(grep -n "^---" "$file" | cut -d: -f1))
    
    if [[ ${#dash_lines} -ge 3 ]]; then
        start_line=${dash_lines[2]}
        end_line=${dash_lines[3]}
        
        # Count non-empty lines between the 2nd and 3rd dash
        content_count=$(sed -n "$((start_line + 1)),$((end_line - 1))p" "$file" | grep -v "^\s*$" | wc -l)
        
        if [[ $content_count -ge 3 ]]; then
            matched_files+=("$file")
        fi
    fi
done

PREV_ARTICLE_LINK=""
if [[ ${#matched_files} -gt 0 ]]; then
    # Sort and take the last one
    last_post=$(echo "${matched_files[@]}" | tr ' ' '\n' | sort | tail -n 1)
    
    # Ensure it starts with ./ if needed, though URL construction handles it.
    # Convert to URL. remove leading ./ if present for cleanliness
    clean_path=${last_post#./}
    PREV_ARTICLE_LINK="${URL_BASE}/${clean_path}"
else
    # Fallback
    PREV_ARTICLE_LINK="${URL_BASE}/"
fi

# 2. NEXT_ARTICLE_LINK Logic
# 2. NEXT_ARTICLE_LINK Logic
# Default to TODAY_YMD as requested
# TARGET_DIR is defined below, so construct path manually here or wait.
# constructing manually:
NEXT_ARTICLE_LINK="${URL_BASE}/${TODAY_YEAR}/${TODAY_MONTH}/${TODAY_YMD}.md"

# 4. Generate Content
TARGET_DIR="${TODAY_YEAR}/${TODAY_MONTH}"
TARGET_FILE="${TARGET_DIR}/${TODAY_YMD}.md"

mkdir -p "$TARGET_DIR"

if [[ -f "$TARGET_FILE" ]]; then
    echo "File $TARGET_FILE already exists. Overwriting..."
fi

# Template Content
cat <<EOF > "$TARGET_FILE"

# ${HEADER_DATE}

---

### [◀️前日へ](${PREV_DAY_LINK})    [翌日へ▶️](${NEXT_DAY_LINK})

---

---

### [◀️前の記事へ](${PREV_ARTICLE_LINK})    [次の記事へ▶️](${NEXT_ARTICLE_LINK})

EOF

echo "Created journal entry: $TARGET_FILE"

# 5. Git Operations
echo "Executing Git Operations..."
git pull origin main
git add .
git commit -m "Add journal for ${TODAY_YMD}"
git push origin main
