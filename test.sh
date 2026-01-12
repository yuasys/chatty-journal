#!/zsh

# 1. zshの再帰検索（**）と拡張パターンを有効化
setopt extended_glob

# 2. 条件に合致するファイルを格納する配列
matched_files=()

# 3. サブディレクトリを含めて YYYY-MM-DD.md 形式のファイルを再帰検索
# (om) は更新日時順、(N) は該当なしでもエラーにしない設定
for file in ./**/[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].md(N); do
    
    # 行頭が --- の行番号を取得
    dash_lines=($(grep -n "^---" "$file" | cut -d: -f1))
    
    # 3つ以上の --- が存在する場合
    if [[ ${#dash_lines} -ge 3 ]]; then
        # zshの配列は1番から始まるため、2番目と3番目のインデックスを指定
        start_line=${dash_lines[2]}
        end_line=${dash_lines[3]}
        
        # 2番目と3番目の区切り線の間の「中身」を抽出し、空行以外をカウント
        # (start+1 から end-1 までの範囲)
        content_count=$(sed -n "$((start_line + 1)),$((end_line - 1))p" "$file" | grep -v "^\s*$" | wc -l)
        
        if [[ $content_count -ge 3 ]]; then
            matched_files+=("$file")
        fi
    fi
done

# 4. 条件に合致した中で「一番最後（アルファベット順＝日付順）」のファイルを変数に代入
if [[ ${#matched_files} -gt 0 ]]; then
    # ソートして最後の要素を取得
    # 変数名にハイフンは使えないため、アンダースコアを使用します
    last_post=$(echo "${matched_files[@]}" | tr ' ' '\n' | sort | tail -n 1)
    
    # 相対パスの形式を整える (./ を付与)
    [[ $last_post != ./* ]] && last_post="./$last_post"
    
    echo "変数 last_post に代入しました:"
    echo "$last_post"
else
    echo "条件に合致するファイルは見つかりませんでした。"
    last_post=""
fi