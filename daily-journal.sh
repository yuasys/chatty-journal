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
# Mac (BSD) date command uses -v
TODAY_YMD=$(date +%Y-%m-%d)
TODAY_YEAR=$(date +%Y)
TODAY_MONTH=$(date +%m)

# Header Date: e.g., 2026年01月17日（土）
# Force Japanese Locale for this command
HEADER_DATE=$(LC_TIME=ja_JP.UTF-8 date "+%Y年%m月%d日（%a）")

# Previous/Next Day (Calculated from Today)
YESTERDAY_YMD=$(date -v-1d +%Y-%m-%d)
TOMORROW_YMD=$(date -v+1d +%Y-%m-%d)

# Generate Paths for Links
PREV_DAY_LINK="${URL_BASE}/${YESTERDAY_YMD:0:4}/${YESTERDAY_YMD:5:2}/${YESTERDAY_YMD}.md"
NEXT_DAY_LINK="${URL_BASE}/${TOMORROW_YMD:0:4}/${TOMORROW_YMD:5:2}/${TOMORROW_YMD}.md"

# 3. 前の記事 (Existing latest journal) logic
# Find all journal files that are NOT today's file and sort them reverse to find the latest
# Pattern: YYYY/MM/YYYY-MM-DD.md
# (N) null glob, (On) sort by name descending

journal_files=( [0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md(NOn) )

PREV_ARTICLE_LINK=""
NEXT_ARTICLE_LINK="${NEXT_DAY_LINK}" # Default to Next Day since next article usually doesn't exist yet

# Iterate to find the first one that is less than today
for f in "${journal_files[@]}"; do
    basename=$(basename "$f" .md)
    if [[ "$basename" < "$TODAY_YMD" ]]; then
        PREV_ARTICLE_LINK="${URL_BASE}/${f}"
        break
    fi
done

# Fallback if no specific previous article found
if [[ -z "$PREV_ARTICLE_LINK" ]]; then
    PREV_ARTICLE_LINK="${URL_BASE}/"
fi

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
