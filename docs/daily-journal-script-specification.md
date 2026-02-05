# daily-journal.shスクリプト作成指示書

## 1. 概要

### 目的
日々のジャーナルエントリを自動生成し、GitHubリポジトリに自動コミット・プッシュするシェルスクリプトを作成する。

### 主要機能
- 最新のジャーナルエントリを検出し、その翌日の日付でエントリを作成
- 前日・翌日へのナビゲーションリンクを自動生成
- コンテンツの有無を判定し、有効な前の記事へのリンクを生成
- 年/月のディレクトリ階層で自動的にファイルを整理
- Git操作（pull, add, commit, push）を自動実行

## 2. 技術仕様

### 実行環境
- **シェル**: zsh
- **OS**: macOS（`date -j` コマンド使用）
- **必須コマンド**: `find`, `grep`, `sed`, `git`, `date`

### ファイル構成
```
リポジトリルート/
├── YYYY/
│   └── MM/
│       └── YYYY-MM-DD.md
└── daily-journal.sh
```

## 3. 実装詳細

### 3.1 基本設定

```bash
#!/bin/zsh

REPO_ROOT="/path/to/repository"
URL_BASE="https://github.com/username/repository/blob/main"
```

**要件:**
- リポジトリのルートディレクトリの絶対パスを設定
- GitHubリポジトリのベースURLを設定

### 3.2 ディレクトリ移動と検証

```bash
if [[ -d "$REPO_ROOT" ]]; then
    cd "$REPO_ROOT" || { echo "Failed to enter $REPO_ROOT"; exit 1; }
else
    echo "Repository directory not found: $REPO_ROOT"
    exit 1
fi
```

**要件:**
- リポジトリディレクトリの存在確認
- ディレクトリ移動の成功確認
- エラー時は適切なメッセージを表示して終了

### 3.3 日付計算ロジック

#### 最新エントリの検出
```bash
LATEST_FILE=$(find . -maxdepth 3 -type f -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md" | sort | tail -1)
```

**要件:**
- `YYYY-MM-DD.md` 形式のファイルを検索（最大3階層まで）
- ソートして最新のファイルを取得
- ファイル名から日付を抽出

#### 「今日」の日付決定
```bash
if [[ -n "$LATEST_FILE" ]]; then
    LATEST_DATE=$(basename "$LATEST_FILE" .md)
    TODAY_YMD=$(date -j -v+1d -f "%Y-%m-%d" "$LATEST_DATE" "+%Y-%m-%d")
else
    TODAY_YMD=$(date +%Y-%m-%d)
fi
```

**要件:**
- 最新エントリが存在する場合: その翌日を「今日」とする
- エントリが存在しない場合: システム日付を使用
- macOSの `date -j` コマンドを使用した日付操作

#### 各種日付フォーマット生成
```bash
TODAY_YEAR=${TODAY_YMD:0:4}
TODAY_MONTH=${TODAY_YMD:5:2}
HEADER_DATE=$(LC_TIME=ja_JP.UTF-8 date -j -f "%Y-%m-%d" "$TODAY_YMD" "+%Y年%m月%d日（%a）")
YESTERDAY_YMD=$(date -j -v-1d -f "%Y-%m-%d" "$TODAY_YMD" "+%Y-%m-%d")
TOMORROW_YMD=$(date -j -v+1d -f "%Y-%m-%d" "$TODAY_YMD" "+%Y-%m-%d")
```

**要件:**
- 年・月を文字列操作で抽出
- 日本語ロケールでヘッダー用日付を生成（例: 2026年01月17日（土））
- 前日・翌日の日付を計算

### 3.4 ナビゲーションリンク生成

#### 前日・翌日リンク
```bash
PREV_DAY_LINK="${URL_BASE}/${YESTERDAY_YMD:0:4}/${YESTERDAY_YMD:5:2}/${YESTERDAY_YMD}.md"
NEXT_DAY_LINK="${URL_BASE}/${TOMORROW_YMD:0:4}/${TOMORROW_YMD:5:2}/${TOMORROW_YMD}.md"
```

**要件:**
- 日付ベースの機械的なリンク生成
- 年/月のディレクトリ階層を含むパス

### 3.5 有効な前の記事の検索

#### 拡張グロブの有効化
```bash
setopt extended_glob
```

#### ファイル検索と有効性判定
```bash
matched_files=()
MIN_DATE_FILE="2025-04-08.md"  # 最小日付フィルタ

for file in ./**/[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].md(N); do
    filename=$(basename "$file")
    
    # 指定日より古いファイルは除外
    [[ "$filename" < "$MIN_DATE_FILE" ]] && continue
    
    # 今日作成する記事より新しいファイルは除外
    [[ "$filename" < "${TODAY_YMD}.md" ]] || continue
    
    # 記事の有効性チェック
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
```

**要件:**
- 日付パターンに一致するマークダウンファイルを再帰検索
- 最小日付フィルタを適用（古すぎるファイルを除外）
- 今日より前の日付のファイルのみを対象
- 有効性判定基準:
  - `---` セパレータが3つ以上存在
  - 2番目と3番目の `---` の間に3行以上のコンテンツ（空行除く）

#### 前の記事リンク生成
```bash
PREV_ARTICLE_LINK=""
if [[ ${#matched_files} -gt 0 ]]; then
    last_post=$(echo "${matched_files[@]}" | tr ' ' '\n' | sort | tail -n 1)
    clean_path=${last_post#./}
    PREV_ARTICLE_LINK="${URL_BASE}/${clean_path}"
else
    PREV_ARTICLE_LINK="${URL_BASE}/"
fi
```

**要件:**
- 有効な記事が見つかった場合: 最新の記事へのリンク
- 見つからない場合: リポジトリルートへのフォールバック

### 3.6 次の記事リンク

```bash
NEXT_ARTICLE_LINK="${URL_BASE}/${TODAY_YEAR}/${TODAY_MONTH}/${TODAY_YMD}.md"
```

**要件:**
- デフォルトで当日の日付へのリンクを設定

### 3.7 ファイル生成

#### ディレクトリ作成
```bash
TARGET_DIR="${TODAY_YEAR}/${TODAY_MONTH}"
TARGET_FILE="${TARGET_DIR}/${TODAY_YMD}.md"
mkdir -p "$TARGET_DIR"
```

**要件:**
- 年/月の階層ディレクトリを自動作成
- すでに存在する場合はエラーにしない（`-p` オプション）

#### テンプレート出力
```bash
cat <<EOF > "$TARGET_FILE"
# ${HEADER_DATE}

---

### [◀️前日へ](${PREV_DAY_LINK})&emsp;&emsp;&emsp;&emsp;[翌日へ▶️](${NEXT_DAY_LINK})

---

---

### [◀️前の記事へ](${PREV_ARTICLE_LINK})&emsp;&emsp;&emsp;&emsp;[次の記事へ▶️](${NEXT_ARTICLE_LINK})
EOF
```

**要件:**
- ヒアドキュメントを使用したテンプレート生成
- 日本語の日付ヘッダー
- 2種類のナビゲーションセクション:
  1. 日付ベースのナビゲーション（前日・翌日）
  2. コンテンツベースのナビゲーション（前の記事・次の記事）
- セパレータ（`---`）で本文エリアを区切る

### 3.8 Git操作の自動実行

```bash
echo "Executing Git Operations..."
git pull origin main
git add .
git commit -m "Add journal for ${TODAY_YMD}"
git push origin main
```

**要件:**
- リモートの最新状態をpull
- 全ての変更をステージング
- 日付を含むコミットメッセージ
- mainブランチへpush

## 4. エラーハンドリング

### 実装すべきエラーチェック
1. リポジトリディレクトリの存在確認
2. ディレクトリ移動の成功確認
3. ファイル作成の確認メッセージ
4. 既存ファイルの上書き警告

## 5. カスタマイズポイント

### 環境依存の設定値
- `REPO_ROOT`: リポジトリのルートパス
- `URL_BASE`: GitHubリポジトリのURL
- `MIN_DATE_FILE`: 最小日付フィルタ（任意設定）

### テンプレートのカスタマイズ
- ヘッダー形式
- ナビゲーションリンクのスタイル
- セパレータの配置

## 6. 使用例

```bash
# スクリプトに実行権限を付与
chmod +x daily-journal.sh

# 実行
./daily-journal.sh
```

### 実行結果例
```
Found latest entry: 2026-02-04. Creating entry for: 2026-02-05
Created journal entry: 2026/02/2026-02-05.md
Executing Git Operations...
Already up to date.
[main a1b2c3d] Add journal for 2026-02-05
 1 file changed, 11 insertions(+)
 create mode 100644 2026/02/2026-02-05.md
```

## 7. 保守・拡張

### 今後の拡張案
コンテンツベースのナビゲーションリンクの自動作成
- 現状では「次の記事」はデフォルトで当日の日付へのリンクを設定している 
- 現状では「前の記事」は新規エントリー作成時に最新のエントリーへのリンクを設定している
- しかし、実際は記事の変更（作成／更新／削除など）により、動的に変化する
- そのため、次のアルゴリズムを実装する必要がある
- - まず、日付ベースのナビゲーションリンクを生成する
- - 次に、コンテンツベースのナビゲーションリンクを生成する
- - その後、コンテンツベースのナビゲーションリンクを日付ベースのナビゲーションリンクに置き換える
- - 最後に、日付ベースのナビゲーションリンクをコンテンツベースのナビゲーションリンクに置き換える
- 留意すべき点
- - 有効な記事と次の有効な記事の間の記事にもリンクを張る必要がある

### 注意事項
- macOS専用（`date -j` コマンド使用）
- Linux環境では `date` コマンドのオプションを変更が必要
- Git認証情報が設定済みであることが前提
