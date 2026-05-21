#!/bin/zsh

# ---------------------------------------------------------
# Navigation Update Script
# Update content-based navigation links for all journal entries
# ---------------------------------------------------------

# 1. 基本設定
REPO_ROOT="/Users/yuasys/source/chatty-journal"
URL_BASE="https://github.com/yuasys/chatty-journal/blob/main"
# 処理対象を動的に決定（実行時から約2ヶ月前より新しい記事のみ）
MIN_DATE_FILE=$(date -j -v-2m "+%Y-%m-%d.md")

# ディレクトリ移動
if [[ -d "$REPO_ROOT" ]]; then
    cd "$REPO_ROOT" || { echo "Failed to enter $REPO_ROOT"; exit 1; }
else
    echo "Repository directory not found: $REPO_ROOT"
    exit 1
fi

# 拡張グロブ有効化
setopt extended_glob

# 2. 有効性判定関数
is_valid_article() {
    local file="$1"
    
    # '---' セパレータの行番号を取得
    local dash_lines=($(grep -n "^---" "$file" | cut -d: -f1))
    
    # 3つ以上の '---' が必要
    [[ ${#dash_lines[@]} -lt 3 ]] && return 1
    
    local start_line=${dash_lines[2]}
    local end_line=${dash_lines[3]}
    
    # 2番目と3番目の '---' の間のコンテンツをカウント
    local content_count=$(sed -n "$((start_line + 1)),$((end_line - 1))p" "$file" | grep -v "^\s*$" | wc -l)
    
    # 1行以上のコンテンツが必要
    [[ $content_count -ge 1 ]] && return 0
    
    return 1
}

# 3. 記事の収集
echo "Collecting articles..."
valid_articles=()
all_articles=()

# 全てのマークダウンファイルを検索
for file in ./**/[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].md(N); do
    filename=$(basename "$file")
    
    # 最小日付フィルタ
    [[ "$filename" < "$MIN_DATE_FILE" ]] && continue
    
    # 全記事リストに追加
    all_articles+=("$file")
    
    # 有効性チェックして有効記事リストに追加
    if is_valid_article "$file"; then
        valid_articles+=("$file")
    fi
done

# 日付順にソート
valid_articles=($(printf '%s\n' "${valid_articles[@]}" | sort))
all_articles=($(printf '%s\n' "${all_articles[@]}" | sort))

total_valid=${#valid_articles[@]}
total_all=${#all_articles[@]}

# 有効な記事が0の場合
if [[ $total_valid -eq 0 ]]; then
    echo "No valid articles found. Nothing to update."
    exit 0
fi

echo "Found $total_valid valid articles out of $total_all total files."

# 4. ファイル更新関数
update_file_navigation() {
    local file="$1"
    local prev_link="$2"
    local next_link="$3"

    local dash_lines=($(grep -n "^---" "$file" | cut -d: -f1))
    local temp_file="${file}.tmp"

    # --- が3つ未満のファイルは不正なフォーマットとみなし、更新しない
    if [[ ${#dash_lines[@]} -lt 3 ]]; then
        echo "    - Warning: Invalid format in '$file' (less than 3 '---' separators). Skipping." >&2
        return 1 # 失敗ステータス
    fi

    # 3番目の '---' と、もしあれば4番目の '---' の間のナビゲーションブロックを置換する
    local nav_start_line=${dash_lines[3]}
    local nav_end_line
    if [[ ${#dash_lines[@]} -ge 4 ]]; then
        nav_end_line=${dash_lines[4]}
    else
        # 4番目の '---' がなければ、ファイルの最後までが対象
        nav_end_line=$(wc -l < "$file")
        ((nav_end_line++)) # 最終行を含めるため
    fi

    # ナビゲーション部分を新しい内容に置き換え
    {
        # 3番目の '---' までをそのまま出力
        sed -n "1,${nav_start_line}p" "$file"

        # 新しいナビゲーションを出力
        echo ""
        echo "### [◀️前の記事へ](${prev_link})&emsp;&emsp;&emsp;&emsp;[次の記事へ▶️](${next_link})"

        # 4番目の '---' があれば、それ以降を出力
        if [[ ${#dash_lines[@]} -ge 4 ]]; then
            sed -n "${nav_end_line},\$p" "$file"
        fi
    } > "$temp_file"

    # 一時ファイルで元のファイルを置き換え
    mv "$temp_file" "$file"

    return 0
}

# 5. ナビゲーションリンクの更新
echo "Updating navigation links..."

for current in "${all_articles[@]}"; do
    current_filename=$(basename "$current")
    current_path=${current#./}
    
    # 前の有効記事を探す
    prev=""
    # 配列を逆順に走査して、現在より小さい最大のものを探すのが効率的だが
    # bash/zshの配列操作で簡易実装：
    # valid_articles はソート済みなので、currentより小さい最後の要素がprev
    
    for v in "${valid_articles[@]}"; do
        v_name=$(basename "$v")
        if [[ "$v_name" < "$current_filename" ]]; then
            prev="$v"
        else
            # current以上になったら終了（ソートされているため）
            break
        fi
    done
    
    # 次の有効記事を探す
    next=""
    for v in "${valid_articles[@]}"; do
        v_name=$(basename "$v")
        if [[ "$v_name" > "$current_filename" ]]; then
            next="$v"
            # 最初に見つかった大きい要素がnext
            break
        fi
    done
    
    # リンクURLの生成
    # デフォルトは自分自身へのリンク（無効記事の場合は特に、前後がない場合の挙動として）
    prev_link="${URL_BASE}/${current_path}"
    next_link="${URL_BASE}/${current_path}"
    
    if [[ -n "$prev" ]]; then
        prev_path=${prev#./}
        prev_link="${URL_BASE}/${prev_path}"
    fi
    
    if [[ -n "$next" ]]; then
        next_path=${next#./}
        next_link="${URL_BASE}/${next_path}"
    fi
    
    # ファイル内のナビゲーション部分を更新
    if update_file_navigation "$current" "$prev_link" "$next_link"; then
        echo "  Updated: $current_path"
    else
        echo "  Failed: $current_path"
    fi
done

# 6. Git操作
echo "Executing Git Operations..."
git pull origin main
git add .
git commit -m "Update navigation links"
git push origin main

echo ""
echo "✓ Successfully processed $total articles."
echo "✓ Changes have been committed and pushed to GitHub."
echo ""
