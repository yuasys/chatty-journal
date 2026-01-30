#!/bin/zsh

# ---------------------------------------------------------
# Daily Journal Automation Script
# ---------------------------------------------------------

# 1. 基本設定
REPO_ROOT="/Users/yuasys/source/chatty-journal"
URL_BASE="https://github.com/yuasys/chatty-journal/blob/main"

# ディレクトリ移動
if [[ -d "$REPO_ROOT" ]]; then
    cd "$REPO_ROOT" || { echo "Failed to enter $REPO_ROOT"; exit 1; }
else
    echo "Repository directory not found: $REPO_ROOT"
    exit 1
fi

# 2. 日付計算
# すべての日誌ファイルを検索 (形式: YYYY/MM/YYYY-MM-DD.md)
# 最新のファイルを見つけ、その翌日を「今日」とする
LATEST_FILE=$(find . -maxdepth 3 -type f -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md" | sort | tail -1)

if [[ -n "$LATEST_FILE" ]]; then
    LATEST_DATE=$(basename "$LATEST_FILE" .md)
    # 最新日付の翌日
    TODAY_YMD=$(date -j -v+1d -f "%Y-%m-%d" "$LATEST_DATE" "+%Y-%m-%d")
    echo "Found latest entry: $LATEST_DATE. Creating entry for: $TODAY_YMD"
else
    # ファイルが見つからない場合は、システムの今日の日付を使用
    TODAY_YMD=$(date +%Y-%m-%d)
    echo "No existing entries found. Creating entry for today: $TODAY_YMD"
fi

TODAY_YEAR=${TODAY_YMD:0:4}
TODAY_MONTH=${TODAY_YMD:5:2}

# ヘッダー用日付フォーマット: 例 2026年01月17日（土）
HEADER_DATE=$(LC_TIME=ja_JP.UTF-8 date -j -f "%Y-%m-%d" "$TODAY_YMD" "+%Y年%m月%d日（%a）")

# 前日と翌日の日付計算（ナビゲーション用）
YESTERDAY_YMD=$(date -j -v-1d -f "%Y-%m-%d" "$TODAY_YMD" "+%Y-%m-%d")
TOMORROW_YMD=$(date -j -v+1d -f "%Y-%m-%d" "$TODAY_YMD" "+%Y-%m-%d")

# リンク用パスの生成
PREV_DAY_LINK="${URL_BASE}/${YESTERDAY_YMD:0:4}/${YESTERDAY_YMD:5:2}/${YESTERDAY_YMD}.md"
NEXT_DAY_LINK="${URL_BASE}/${TOMORROW_YMD:0:4}/${TOMORROW_YMD:5:2}/${TOMORROW_YMD}.md"

# 3. 前の記事へのリンクロジック
# 有効な過去の記事（コンテンツが含まれるもの）を検索

setopt extended_glob

matched_files=()
MIN_DATE_FILE="2025-04-08.md"

# 過去のマークダウンファイルを再帰的に検索
for file in ./**/[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].md(N); do
    filename=$(basename "$file")
    
    # 指定日より古いファイルは除外
    [[ "$filename" < "$MIN_DATE_FILE" ]] && continue

    # 今日作成する記事より新しいファイルは除外
    [[ "$filename" < "${TODAY_YMD}.md" ]] || continue
    
    # 記事の有効性チェック（メタデータセパレータ '---' が3つ以上あり、本文があるか）
    dash_lines=($(grep -n "^---" "$file" | cut -d: -f1))
    
    if [[ ${#dash_lines} -ge 3 ]]; then
        start_line=${dash_lines[2]}
        end_line=${dash_lines[3]}
        
        # 2番目と3番目の '---' の間に空行以外のコンテンツがあるかカウント
        content_count=$(sed -n "$((start_line + 1)),$((end_line - 1))p" "$file" | grep -v "^\s*$" | wc -l)
        
        if [[ $content_count -ge 3 ]]; then
            matched_files+=("$file")
        fi
    fi
done

PREV_ARTICLE_LINK=""
if [[ ${#matched_files} -gt 0 ]]; then
    # ソートして最後の1つ（直近の過去記事）を取得
    last_post=$(echo "${matched_files[@]}" | tr ' ' '\n' | sort | tail -n 1)
    
    # URL生成（先頭の ./ を削除）
    clean_path=${last_post#./}
    PREV_ARTICLE_LINK="${URL_BASE}/${clean_path}"
else
    # 記事が見つからない場合のフォールバック
    PREV_ARTICLE_LINK="${URL_BASE}/"
fi

# 2. 次の記事へのリンクロジック
# デフォルトで当日へのリンクを設定
NEXT_ARTICLE_LINK="${URL_BASE}/${TODAY_YEAR}/${TODAY_MONTH}/${TODAY_YMD}.md"

# 4. 記事ファイルの生成
TARGET_DIR="${TODAY_YEAR}/${TODAY_MONTH}"
TARGET_FILE="${TARGET_DIR}/${TODAY_YMD}.md"

mkdir -p "$TARGET_DIR"

if [[ -f "$TARGET_FILE" ]]; then
    echo "File $TARGET_FILE already exists. Overwriting..."
fi

# テンプレートの書き込み
cat <<EOF > "$TARGET_FILE"

# ${HEADER_DATE}

---

### [◀️前日へ](${PREV_DAY_LINK})    [翌日へ▶️](${NEXT_DAY_LINK})

---

---

### [◀️前の記事へ](${PREV_ARTICLE_LINK})    [次の記事へ▶️](${NEXT_ARTICLE_LINK})

EOF

echo "Created journal entry: $TARGET_FILE"

# 5. Git操作の実行
echo "Executing Git Operations..."
git pull origin main
git add .
git commit -m "Add journal for ${TODAY_YMD}"
git push origin main
