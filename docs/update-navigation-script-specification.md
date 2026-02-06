# update-navigation.sh スクリプト実装計画書

## 1. 概要

### 目的
既存の全てのジャーナルエントリに対して、コンテンツベースのナビゲーションリンク（前の記事・次の記事）を動的に更新するスクリプトを作成する。

### 背景
`daily-journal.sh` は新規エントリ作成時に「前の記事」へのリンクを生成するが、記事の作成・更新・削除により、既存エントリのリンクが古くなる問題がある。このスクリプトは全エントリのリンクを最新状態に保つ。

### スコープ
- **対象**: リポジトリ内の全ての有効なジャーナルエントリ
- **更新内容**: コンテンツベースのナビゲーションリンク（日付ベースのリンクは対象外）
- **実行タイミング**: 手動実行、または記事更新後

## 2. 技術仕様

### 実行環境
- **シェル**: zsh
- **OS**: macOS
- **前提条件**: `daily-journal.sh` と同じリポジトリ構造

### 処理対象ファイル
```
リポジトリルート/
└── YYYY/
    └── MM/
        └── YYYY-MM-DD.md
```

## 3. アルゴリズム設計

### 3.1 全体フロー

```
1. 有効な記事の収集
   ↓
2. 日付順にソート
   ↓
3. 各記事について前後の記事を特定
   ↓
4. コンテンツナビゲーション部分を更新
   ↓
5. Git操作（オプション）
```

### 3.2 詳細処理フロー

#### Phase 1: 有効な記事の収集

```bash
#!/bin/zsh

# 基本設定
REPO_ROOT="/Users/yuasys/source/chatty-journal"
URL_BASE="https://github.com/yuasys/chatty-journal/blob/main"
MIN_DATE_FILE="2025-04-08.md"

cd "$REPO_ROOT" || exit 1

# 拡張グロブ有効化
setopt extended_glob

# 有効な記事を格納する配列
valid_articles=()

# 全てのマークダウンファイルを検索
for file in ./**/[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].md(N); do
    filename=$(basename "$file")
    
    # 最小日付フィルタ
    [[ "$filename" < "$MIN_DATE_FILE" ]] && continue
    
    # 有効性チェック（daily-journal.shと同じロジック）
    if is_valid_article "$file"; then
        valid_articles+=("$file")
    fi
done

# 日付順にソート
valid_articles=($(printf '%s\n' "${valid_articles[@]}" | sort))
```

**要件:**
- `daily-journal.sh` と同じ有効性判定ロジックを使用
- 日付でソート（古い順）
- 最小日付フィルタを適用

#### Phase 2: 有効性判定関数

```bash
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
```

**要件:**
- `---` セパレータが3つ以上
- 2番目と3番目の間に1行以上の非空行コンテンツ
- 記事の本文が存在することを最低限保証する

#### Phase 3: ナビゲーションリンクの更新

```bash
update_navigation_links() {
    local total=${#valid_articles[@]}
    
    echo "Updating navigation for $total valid articles..."
    
    for ((i=1; i<=total; i++)); do
        local current="${valid_articles[$i]}"
        local current_path=${current#./}
        
        # 前の記事（存在しない場合は空）
        local prev=""
        if [[ $i -gt 1 ]]; then
            prev="${valid_articles[$((i-1))]}"
        fi
        
        # 次の記事（存在しない場合は空）
        local next=""
        if [[ $i -lt $total ]]; then
            next="${valid_articles[$((i+1))]}"
        fi
        
        # リンクURLの生成
        # デフォルトは自分自身へのリンク
        local prev_link="${URL_BASE}/${current_path}"
        local next_link="${URL_BASE}/${current_path}"
        
        if [[ -n "$prev" ]]; then
            local prev_path=${prev#./}
            prev_link="${URL_BASE}/${prev_path}"
        fi
        
        if [[ -n "$next" ]]; then
            local next_path=${next#./}
            next_link="${URL_BASE}/${next_path}"
        fi
        
        # ファイル内のナビゲーション部分を更新
        update_file_navigation "$current" "$prev_link" "$next_link"
        
        echo "Updated: $current_path"
    done
}
```

**要件:**
- 配列のインデックスで前後の記事を特定（Zshの1始まりインデックスを利用）
- 最初の記事: 前の記事リンクは自分自身（またはルート）へ
- 最後の記事: 次の記事リンクは自分自身（またはルート）へ
- 中間の記事: 前後の記事への有効なリンク

#### Phase 4: ファイル内容の更新

```bash
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
    
    local nav_start=${dash_lines[3]}  # 3番目の '---' の行
    
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
}
```

**要件:**
- 3番目の `---` セパレータまでの内容を保持
- その後のナビゲーション部分を新しいリンクで置き換え
- 一時ファイルを使用して安全に更新
- エラーハンドリング（3つの `---` がない場合はスキップ）

## 4. エッジケース処理

### 4.1 有効な記事が1つの場合

```bash
if [[ $total -eq 1 ]]; then
    # 前も次も自分自身（または設定されたデフォルト）へのリンク
    prev_link="${URL_BASE}/${current_path}"
    next_link="${URL_BASE}/${current_path}"
fi
```

### 4.2 有効な記事が0の場合

```bash
if [[ $total -eq 0 ]]; then
    echo "No valid articles found. Nothing to update."
    exit 0
fi
```

### 4.3 ファイルが不正な構造の場合

```bash
# update_file_navigation 関数内でチェック
if [[ ${#dash_lines[@]} -lt 3 ]]; then
    echo "Warning: $file does not have 3 '---' separators. Skipping..."
    return 1
fi
```

### 4.4 中間に無効な記事がある場合

```
有効な記事A (2026-02-01.md)
無効な記事  (2026-02-02.md) ← スキップ
有効な記事B (2026-02-03.md)
```

- 記事Aの「次の記事」は記事Bへリンク（2026-02-02.md は飛ばす）
- 記事Bの「前の記事」は記事Aへリンク

## 5. エラーハンドリング

### 実装されているチェック
1. リポジトリディレクトリの存在確認
2. ディレクトリ移動の成功確認
3. ファイルが有効な構造（3つの `---`）を持っているかの確認
4. 有効な記事が見つからない場合の終了処理

### エラーメッセージ例
```bash
echo "Repository directory not found: $REPO_ROOT"
echo "Warning: $file does not have 3 '---' separators. Skipping..."
echo "No valid articles found. Nothing to update."
```

## 6. Git操作

最新のスクリプトでは、実行の最後に以下のGit操作を自動で行います。

```bash
echo "Executing Git Operations..."
git pull origin main
git add .
git commit -m "Update navigation links"
git push origin main
```

**要件:**
- リモートの最新状態を pull する
- 全ての変更をステージングする
- 固定のメッセージでコミットする
- mainブランチへ push する

## 7. daily-journal.sh との統合

### 推奨される方法: 直接呼び出し

`daily-journal.sh` の最後に追加することで、新規記事作成時に全体の整合性を保つことができます。

```bash
# daily-journal.sh の末尾
echo "Updating all navigation links..."
./update-navigation.sh
```

## 8. 使用例

### 基本実行
```bash
chmod +x update-navigation.sh
./update-navigation.sh
```

### 実行結果例
```
Collecting valid articles...
Found 34 valid articles.
Updating navigation links...
  [1/34] Updated: 2025/12/2025-12-13.md
  [2/34] Updated: 2025/12/2025-12-20.md
  ...
Executing Git Operations...
✓ Successfully processed 34 articles.
✓ Changes have been committed and pushed to GitHub.
```

## 9. パフォーマンス考慮

### 対象ファイル数が多い場合
- 進捗表示の追加（例: 10件ごとに表示）
- バッチ処理の検討

### 最適化オプション
```bash
# 特定の日付範囲のみ更新
START_DATE="2026-02-01"
END_DATE="2026-02-28"

for file in valid_articles; do
    filename=$(basename "$file" .md)
    [[ "$filename" < "$START_DATE" || "$filename" > "$END_DATE" ]] && continue
    # 更新処理...
done
```

## 10. テスト計画

### テストケース
1. **正常系**: 複数の有効な記事がある場合
2. **境界値**: 記事が1つだけの場合
3. **境界値**: 記事が0の場合
4. **異常系**: 不正な構造のファイルが混在する場合
5. **異常系**: 中間に無効な記事がある場合

### テスト手順
```bash
# 1. バックアップを作成
cp -r 2026 2026.backup

# 2. スクリプトを実行
./update-navigation.sh

# 3. 結果を確認
git diff

# 4. 問題があればロールバック
rm -rf 2026
mv 2026.backup 2026
```

## 11. 保守・拡張

### 今後の拡張案
- ドライランモード（`--dry-run`）の追加
- 特定ファイルのみ更新するオプション
- 並列処理による高速化
- ログファイル出力

### 設定ファイル化
環境変数や設定を外部ファイルに分離:
```bash
# config.sh
REPO_ROOT="/Users/yuasys/source/chatty-journal"
URL_BASE="https://github.com/yuasys/chatty-journal/blob/main"
MIN_DATE_FILE="2025-04-08.md"
AUTO_COMMIT=false
```

## 12. 注意事項

> [!WARNING]
> このスクリプトは全てのエントリファイルを書き換えます。実行前に必ずバックアップを取るか、Git でコミットしてから実行してください。

> [!IMPORTANT]
> このスクリプトは `daily-journal.sh` と同じ有効性判定ロジックを使用します。判定基準を変更する場合は、両方のスクリプトを同期して更新してください。

> [!TIP]
> 初回実行時は `git diff` で変更内容を確認してから、問題なければコミットすることを推奨します。
