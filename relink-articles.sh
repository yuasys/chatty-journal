#!/bin/zsh

# ---------------------------------------------------------
# Design Intent: 記事が存在するファイル間を正しいリンクで結び直す
# ---------------------------------------------------------

# 1. 基本設定
REPO_ROOT="/Users/yuasys/source/chatty-journal"
URL_BASE="https://github.com/yuasys/chatty-journal/blob/main"
MIN_DATE_FILE="2025-04-08.md"

cd "$REPO_ROOT" || exit 1

# 2. 全ファイルから「有効な記事」を持つファイルだけを抽出
# 昇順でソートすることで、配列の [i-1] が過去、[i+1] が未来になるようにする
setopt extended_glob
valid_article_files=()

echo "Searching for valid articles..."

# 日付形式のファイルをすべて取得し、昇順ソート
for file in ./**/[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].md(Nn); do
    filename=$(basename "$file")
    [[ "$filename" < "$MIN_DATE_FILE" ]] && continue

    # 記事有効性チェック (ユーザー提供のロジックを継承)
    dash_lines=($(grep -n "^---" "$file" | cut -d: -f1))
    if [[ ${#dash_lines} -ge 3 ]]; then
        start_line=${dash_lines[2]}
        end_line=${dash_lines[3]}
        content_count=$(sed -n "$((start_line + 1)),$((end_line - 1))p" "$file" | grep -v "^\s*$" | wc -l)
        
        # 本文が3行以上あれば「有効な記事」とみなす
        if [[ $content_count -ge 3 ]]; then
            valid_article_files+=("$file")
        fi
    fi
done

total=${#valid_article_files}
echo "Found $total valid articles. Starting relink process..."

# 3. リンクの更新（再リンク処理）
for (( i=1; i<=$total; i++ )); do
    current_file=${valid_article_files[$i]}
    
    # 前の記事（過去方向）
    if [[ $i -gt 1 ]]; then
        prev_file=${valid_article_files[$((i-1))]}
        prev_path=${prev_file#./}
        PREV_LINK="${URL_BASE}/${prev_path}"
    else
        PREV_LINK="${URL_BASE}/" # 最初の記事の場合
    fi

    # 次の記事（未来方向）
    if [[ $i -lt $total ]]; then
        next_file=${valid_article_files[$((i+1))]}
        next_path=${next_file#./}
        NEXT_LINK="${URL_BASE}/${next_path}"
    else
        # 最後の記事の場合、自分自身またはリポジトリトップ
        NEXT_LINK="${URL_BASE}/${current_file#./}"
    fi

    # ファイル内の「前の記事へ」の行を特定して書き換え
    # デザイン意図：sed を使って、特定のパターンを持つ行を生成したリンクで置換する
    NEW_LINE="### [◀️前の記事へ](${PREV_LINK})    [次の記事へ▶️](${NEXT_LINK})"
    
    # 一時ファイルを使って安全に置換
    sed -e "s|### \[◀️前の記事へ\].*|${NEW_LINE}|" "$current_file" > "${current_file}.tmp" && mv "${current_file}.tmp" "$current_file"
    
    echo "Updated: $current_file"
done

echo "Relink completed."
