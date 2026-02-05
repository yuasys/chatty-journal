#!/bin/zsh

# ---------------------------------------------------------
# Navigation Update Script
# Update content-based navigation links for all journal entries
# ---------------------------------------------------------

# 1. 基本設定
REPO_ROOT="/Users/yuasys/source/chatty-journal"
URL_BASE="https://github.com/yuasys/chatty-journal/blob/main"
MIN_DATE_FILE="2025-04-08.md"

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

# 3. 有効な記事の収集
echo "Collecting valid articles..."
valid_articles=()

# 全てのマークダウンファイルを検索
for file in ./**/[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].md(N); do
    filename=$(basename "$file")
    
    # 最小日付フィルタ
    [[ "$filename" < "$MIN_DATE_FILE" ]] && continue
    
    # 有効性チェック
    if is_valid_article "$file"; then
        valid_articles+=("$file")
    fi
done

# 日付順にソート
valid_articles=($(printf '%s\n' "${valid_articles[@]}" | sort))

total=${#valid_articles[@]}

# 有効な記事が0の場合
if [[ $total -eq 0 ]]; then
    echo "No valid articles found. Nothing to update."
    exit 0
fi

echo "Found $total valid articles."

# 4. ファイル更新関数
update_file_navigation() {
    local file="$1"
    local prev_link="$2"
    local next_link="$3"
    
    # 一時ファイルを作成
    local temp_file="${file}.tmp"
    
    # '---' セパレータの位置を特定
    local dash_lines=($(grep -n "^---" "$file" | cut -d: -f1))
    
    if [[ ${#dash_lines[@]} -lt 3 ]]; then
        echo "Warning: $file does not have 3 '---' separators. Skipping..."
        return 1
    fi
    
    local nav_start=${dash_lines[3]}  # 3番目の '---' の行（インデックスは1始まり）
    
    # ナビゲーション部分を新しい内容に置き換え
    {
        # 3番目の '---' までをそのまま出力
        sed -n "1,${nav_start}p" "$file"
        
        # 新しいナビゲーションを出力
        echo ""
        echo "### [◀️前の記事へ](${prev_link})&emsp;&emsp;&emsp;&emsp;[次の記事へ▶️](${next_link})"
    } > "$temp_file"
    
    # 一時ファイルで元のファイルを置き換え
    mv "$temp_file" "$file"
    
    return 0
}

# 5. ナビゲーションリンクの更新
echo "Updating navigation links..."

for ((i=1; i<=total; i++)); do
    current="${valid_articles[$i]}"
    current_path=${current#./}
    
    # 前の記事（存在しない場合は空）
    prev=""
    if [[ $i -gt 1 ]]; then
        prev="${valid_articles[$((i-1))]}"
    fi
    
    # 次の記事（存在しない場合は空）
    next=""
    if [[ $i -lt $total ]]; then
        next="${valid_articles[$((i+1))]}"
    fi
    
    # リンクURLの生成
    # デフォルトは自分自身へのリンク
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
        echo "  [$i/$total] Updated: $current_path"
    else
        echo "  [$i/$total] Skipped: $current_path"
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
