#!/bin/zsh

# ---------------------------------------------------------
# Daily Journal Automation Script (Test Version)
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
# Search depth 3 (./YYYY/MM/file.md) -- strict pattern to avoid false positives
setopt extended_glob
all_files=( ./**/[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].md(N) )

# Sort files to find the absolute latest
sorted_files=("${(@o)all_files}")
LATEST_FILE=${sorted_files[-1]}

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
HEADER_DATE=$(LC_TIME=ja_JP.UTF-8 date -j -f "%Y-%m-%d" "$TODAY_YMD" "+%Y年%m月%d日（%a）")

# Previous/Next Day (Calculated from TODAY_YMD) for the date nav (not article nav)
YESTERDAY_YMD=$(date -j -v-1d -f "%Y-%m-%d" "$TODAY_YMD" "+%Y-%m-%d")
TOMORROW_YMD=$(date -j -v+1d -f "%Y-%m-%d" "$TODAY_YMD" "+%Y-%m-%d")

PREV_DAY_LINK="${URL_BASE}/${YESTERDAY_YMD:0:4}/${YESTERDAY_YMD:5:2}/${YESTERDAY_YMD}.md"
NEXT_DAY_LINK="${URL_BASE}/${TOMORROW_YMD:0:4}/${TOMORROW_YMD:5:2}/${TOMORROW_YMD}.md"

# 3. Find Neighbors (PREV_ARTICLE and NEXT_ARTICLE)
# We need to find the file chronologically immediately before and after TODAY_YMD.
# Since we already have sorted_files, we can iterate.

PREV_FILE=""
NEXT_FILE=""

# Target filename relative to repo root would be looked like:
TARGET_BASENAME="${TODAY_YMD}.md"

for file in "${sorted_files[@]}"; do
    filename=$(basename "$file")
    
    if [[ "$filename" < "$TARGET_BASENAME" ]]; then
        PREV_FILE="$file"
    elif [[ "$filename" > "$TARGET_BASENAME" ]]; then
        NEXT_FILE="$file"
        break  # Found the immediate next, stop searching
    fi
done

# Logic to construct URLs
# URL construction helper
get_url_from_file() {
    local fPath=$1
    if [[ -z "$fPath" ]]; then
        # Return base if empty, or handle gracefully?
        # Requirement implies "Next Article" link should be empty or default if none.
        # But wait, existing code puts URL_BASE/ for default.
        echo "${URL_BASE}/"
        return
    fi
    # remove leading ./
    local cleanPath=${fPath#./}
    echo "${URL_BASE}/${cleanPath}"
}

PREV_ARTICLE_LINK=$(get_url_from_file "$PREV_FILE")
NEXT_ARTICLE_LINK=$(get_url_from_file "$NEXT_FILE")

echo "Previous Article: $PREV_FILE"
echo "Next Article:     $NEXT_FILE"

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

# 5. Patching Neighbors (Dynamic Updates)

# Helper function to escape for sed
escape_sed() {
    echo "$1" | sed -e 's/[]\/$*.^[]/\\&/g'
}

MY_ARTICLE_LINK="${URL_BASE}/${TODAY_YEAR}/${TODAY_MONTH}/${TODAY_YMD}.md"

# Pattern to look for in files:
# ### [◀️前の記事へ](...)    [次の記事へ▶️](...)
# We can use regex to replace the specific part.

if [[ -n "$PREV_FILE" && -f "$PREV_FILE" ]]; then
    echo "Updating Previous Article: $PREV_FILE"
    # Update the "Next Article" link in the previous file to point to ME.
    # We want to replace the second link: [次の記事へ▶️](...)
    
    # We will look for the line containing [次の記事へ▶️]
    # And replace the URL inside the parenthesis.
    
    # Construct the substitution.
    # It attempts to match: [次の記事へ▶️](ANYTHING) and replace with [次の記事へ▶️](MY_LINK)
    # Note:   is U+2003 (Em Space). The file seems to use it based on previous cat.
    # Safest is to match the text "[次の記事へ▶️](" until ")"
    
    sed -i '' "s|\[次の記事へ▶️\]([^)]*)|[次の記事へ▶️](${MY_ARTICLE_LINK})|g" "$PREV_FILE"
fi

if [[ -n "$NEXT_FILE" && -f "$NEXT_FILE" ]]; then
    echo "Updating Next Article: $NEXT_FILE"
    # Update the "Previous Article" link in the next file to point to ME.
    # Replace [◀️前の記事へ](ANYTHING) with [◀️前の記事へ](MY_LINK)
    
    sed -i '' "s|\[◀️前の記事へ\]([^)]*)|[◀️前の記事へ](${MY_ARTICLE_LINK})|g" "$NEXT_FILE"
fi

# 6. Git Operations
echo "Executing Git Operations..."
git pull origin main
git add .
git commit -m "Add journal for ${TODAY_YMD} and update links"
git push origin main
