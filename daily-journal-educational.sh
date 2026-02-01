#!/bin/zsh

# ---------------------------------------------------------
# Daily Journal Automation Script (Educational Version)
# ---------------------------------------------------------
#
# 【このスクリプトの目的】
# 日々の業務日誌作成の手間を省き、継続しやすくすること。
# 手動で行う「日付計算」「ファイル作成」「リンク作成」「Git保存」を全自動化します。

# =========================================================
# 1. 基本設定 (Configuration)
# =========================================================
# 【意図】
# スクリプト内で使うパスやURLを冒頭で変数化しておくことで、
# 将来リポジトリの場所やURLが変わった時にここだけ直せば済むようにしています。
REPO_ROOT="/Users/yuasys/source/chatty-journal"
URL_BASE="https://github.com/yuasys/chatty-journal/blob/main"

# 【意図】
# cronや自動実行ツールから呼び出された場合、カレントディレクトリが保証されないため、
# 明示的にリポジトリのルートへ移動してから処理を開始します。
if [[ -d "$REPO_ROOT" ]]; then
    cd "$REPO_ROOT" || { echo "Failed to enter $REPO_ROOT"; exit 1; }
else
    echo "Repository directory not found: $REPO_ROOT"
    exit 1
fi

# =========================================================
# 2. 日付計算ロジック (Date Calculation)
# =========================================================
# 【意図】
# 単に「今日の日付」で作ると、週末にまとめて書く場合や、
# すでに今日の日誌がある場合に上書きしてしまうリスクがあります。
# そのため、「既存の最新日記の翌日」を自動的にターゲット日として計算もできるように、
# 最新ファイルを検索するロジックを入れています。

# 検索条件: ./**/YYYY-MM-DD.md 形式のファイルを深さ3階層まで探す
LATEST_FILE=$(find . -maxdepth 3 -type f -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md" | sort | tail -1)

if [[ -n "$LATEST_FILE" ]]; then
    LATEST_DATE=$(basename "$LATEST_FILE" .md)
    # 【意図】
    # 最新ファイルが見つかった場合は「その翌日」を今回作成する日付とします。
    # これにより、毎日実行し忘れても連続した日付で作成できます。
    TODAY_YMD=$(date -j -v+1d -f "%Y-%m-%d" "$LATEST_DATE" "+%Y-%m-%d")
    echo "Found latest entry: $LATEST_DATE. Creating entry for: $TODAY_YMD"
else
    # 【意図】
    # 初回実行時など、過去ファイルが一つもない場合のフォールバック（安全策）です。
    TODAY_YMD=$(date +%Y-%m-%d)
    echo "No existing entries found. Creating entry for today: $TODAY_YMD"
fi

TODAY_YEAR=${TODAY_YMD:0:4}
TODAY_MONTH=${TODAY_YMD:5:2}

# 【意図】
# 記事タイトル用に見やすい日本語の日付フォーマットを用意します。
HEADER_DATE=$(LC_TIME=ja_JP.UTF-8 date -j -f "%Y-%m-%d" "$TODAY_YMD" "+%Y年%m月%d日（%a）")

# =========================================================
# 3. ナビゲーションリンクの準備 (Link Preparation)
# =========================================================
# 【意図】
# Web上で閲覧した際に、前後の日付にスムーズに移動できるように
# 前日・翌日へのリンクを予め計算しておきます。
YESTERDAY_YMD=$(date -j -v-1d -f "%Y-%m-%d" "$TODAY_YMD" "+%Y-%m-%d")
TOMORROW_YMD=$(date -j -v+1d -f "%Y-%m-%d" "$TODAY_YMD" "+%Y-%m-%d")

PREV_DAY_LINK="${URL_BASE}/${YESTERDAY_YMD:0:4}/${YESTERDAY_YMD:5:2}/${YESTERDAY_YMD}.md"
NEXT_DAY_LINK="${URL_BASE}/${TOMORROW_YMD:0:4}/${TOMORROW_YMD:5:2}/${TOMORROW_YMD}.md"

# =========================================================
# 4. 前の記事へのリンク検索 (Previous Article Search)
# =========================================================
# 【意図】
# 「前日」と「前の記事」は必ずしも一致しません（週末などで空いた場合）。
# 確実に存在する過去の最新記事にリンクさせるため、実ファイルを再走査します。

setopt extended_glob # 高度なファイルマッチングを有効化

matched_files=()
MIN_DATE_FILE="2025-04-08.md" # これより古いファイルは無視するフィルタリングリング

for file in ./**/[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].md(N); do
    filename=$(basename "$file")
    
    # 【意図】範囲外の古いファイルや、未来のファイルは除外
    [[ "$filename" < "$MIN_DATE_FILE" ]] && continue
    [[ "$filename" < "${TODAY_YMD}.md" ]] || continue
    
    # 【意図】
    # 空のファイル（作成だけして書いてない記事）へのリンクを防ぐため、
    # 実際に本文が書かれているか（---区切りのメタデータの後に中身があるか）をチェックします。
    # これにより「中身のある前回の記事」へ確実にリンクできます。
    dash_lines=($(grep -n "^---" "$file" | cut -d: -f1))
    
    if [[ ${#dash_lines} -ge 3 ]]; then
        start_line=${dash_lines[2]}
        end_line=${dash_lines[3]}
        content_count=$(sed -n "$((start_line + 1)),$((end_line - 1))p" "$file" | grep -v "^\s*$" | wc -l)
        
        if [[ $content_count -ge 3 ]]; then
            matched_files+=("$file")
        fi
    fi
done

PREV_ARTICLE_LINK=""
if [[ ${#matched_files} -gt 0 ]]; then
    last_post=$(echo "${matched_files[@]}" | tr ' ' '\n' | sort | tail -n 1)
    clean_path=${last_post#./}
    PREV_ARTICLE_LINK="${URL_BASE}/${clean_path}"
else
    # 見つからない場合はトップページなどを設定（リンク切れ防止）
    PREV_ARTICLE_LINK="${URL_BASE}/"
fi

# 次の記事はまだ存在しないため、デフォルト（自分自身）または空を設定
NEXT_ARTICLE_LINK="${URL_BASE}/${TODAY_YEAR}/${TODAY_MONTH}/${TODAY_YMD}.md"

# =========================================================
# 5. ファイル生成 (File Generation)
# =========================================================
TARGET_DIR="${TODAY_YEAR}/${TODAY_MONTH}"
TARGET_FILE="${TARGET_DIR}/${TODAY_YMD}.md"

# 【意図】保存先のディレクトリが存在しないとエラーになるため、事前に作成
mkdir -p "$TARGET_DIR"

if [[ -f "$TARGET_FILE" ]]; then
    echo "File $TARGET_FILE already exists. Overwriting..."
fi

# 【意図】
# ヒアドキュメント(cat <<EOF)を使ってテンプレートを一気に書き込みます。
# 変数 (${VAR}) を埋め込むことで、毎回手入力する手間を完全に省いています。
cat <<EOF > "$TARGET_FILE"

# ${HEADER_DATE}

---

### [◀️前日へ](${PREV_DAY_LINK})    [翌日へ▶️](${NEXT_DAY_LINK})

---

---

### [◀️前の記事へ](${PREV_ARTICLE_LINK})    [次の記事へ▶️](${NEXT_ARTICLE_LINK})

EOF

echo "Created journal entry: $TARGET_FILE"

# =========================================================
# 6. Git自動保存 (Git Operations)
# =========================================================
# 【意図】
# 「書いたのに保存（commit/push）し忘れた」を防ぐため、
# ファイル作成と同時にリポジトリへ同期させます。
echo "Executing Git Operations..."
git pull origin main
git add .
git commit -m "Add journal for ${TODAY_YMD}"
git push origin main
