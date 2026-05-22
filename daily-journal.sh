#!/bin/zsh

# コマンドが失敗した場合にスクリプトを即座に終了させる
set -e
set -o pipefail

# 1. 基本設定
REPO_ROOT="/Users/yuasys/source/chatty-journal"
URL_BASE="https://github.com/yuasys/chatty-journal/blob/main"
SCRIPT_DIR=$(dirname "$0")

# 2. リポジトリのルートへ移動
cd "$REPO_ROOT" || { echo "Failed to enter $REPO_ROOT"; exit 1; }

# 3. 日付変数を生成 (generate_entry.sh を利用)
# このスクリプトは内部で最新ファイルを検索し、TODAY, TITLE_DATE 等の変数を設定する
source "${SCRIPT_DIR}/generate_entry.sh"

# 4. ナビゲーションリンクを準備
# 4-1. 前日/翌日リンク
PREV_DAY_LINK="${URL_BASE}/${YESTERDAY_STR}"
NEXT_DAY_LINK="${URL_BASE}/${TOMORROW_STR}"

# 4-2. 前の記事/次の記事リンク
# find_latest_post.sh を使い、今日より前の「有効な」最新記事を探す
LAST_POST_PATH=$("${SCRIPT_DIR}/find_latest_post.sh" "${TODAY}.md")

if [[ -n "$LAST_POST_PATH" ]]; then
    clean_path=${LAST_POST_PATH#./}
    PREV_ARTICLE_LINK="${URL_BASE}/${clean_path}"
else
    # 見つからない場合はリポジトリのトップへ
    PREV_ARTICLE_LINK="${URL_BASE}/"
fi
# 「次の記事」はまだ存在しないため、作成する自分自身へのリンクを設定
NEXT_ARTICLE_LINK="${URL_BASE}/${TARGET_DIR}/${TODAY}.md"

# 4. 記事ファイルの生成
TARGET_FILE="${TARGET_DIR}/${TODAY}.md"

# ディレクトリがなければ作成
mkdir -p "$TARGET_DIR"

if [[ -f "$TARGET_FILE" ]]; then
    echo "File $TARGET_FILE already exists. Overwriting..."
fi

# ヒアドキュメントでテンプレートを書き込む
cat <<EOF > "$TARGET_FILE"
# ${TITLE_DATE}

---

### [◀️前日へ](${PREV_DAY_LINK})&emsp;&emsp;&emsp;&emsp;[翌日へ▶️](${NEXT_DAY_LINK})

---

---

### [◀️前の記事へ](${PREV_ARTICLE_LINK})&emsp;&emsp;&emsp;&emsp;[次の記事へ▶️](${NEXT_ARTICLE_LINK})
EOF

echo "Created journal entry: $TARGET_FILE"

# 5. Git操作の実行
echo "Executing Git Operations..."
git pull origin main
git add .
git commit -m "Add journal for ${TODAY}"
git push origin main

echo "✓ Journal entry for ${TODAY} created and pushed successfully."
