# 日誌自動化スクリプト 図解ガイド（初心者向け）

## このスクリプトが何をするのか

**一言で言うと**: 「毎日の日誌ファイルを、日付計算からGit保存まで全自動で作ってくれる便利ツール」

### 手作業 vs スクリプト自動化の比較

```mermaid
graph LR
    subgraph 手作業の場合 [⏱️ 約5分]
    A1[今日の日付確認] --> A2[フォルダ作成]
    A2 --> A3[ファイル作成]
    A3 --> A4[日付を手入力]
    A4 --> A5[前後のリンク手入力]
    A5 --> A6[Git commit]
    A6 --> A7[Git push]
    end
    
    subgraph スクリプト実行 [⚡ 約5秒]
    B1[./daily-journal.sh] --> B2[完成！]
    end
    
    style B1 fill:#90EE90
    style B2 fill:#FFD700
```

**7ステップ → 1ステップ** に短縮！時間も **60倍速** に！

---

## スクリプトの全体像（処理の流れ）

```mermaid
flowchart TD
    Start([スクリプト開始]) --> Step1[ステップ1<br/>📂 作業場所の準備]
    
    Step1 --> Step2[ステップ2<br/>📅 日付の自動計算]
    
    Step2 --> Step3[ステップ3<br/>🔗 リンクURLの準備]
    
    Step3 --> Step4[ステップ4<br/>🔍 前の記事を探す]
    
    Step4 --> Step5[ステップ5<br/>📝 ファイル生成]
    
    Step5 --> Step6[ステップ6<br/>💾 Git自動保存]
    
    Step6 --> End([完了！])
    
    style Start fill:#E8F5E9
    style End fill:#C8E6C9
    style Step1 fill:#FFF9C4
    style Step2 fill:#FFE0B2
    style Step3 fill:#FFCCBC
    style Step4 fill:#F8BBD0
    style Step5 fill:#E1BEE7
    style Step6 fill:#B2EBF2
```

---

## 各ステップの詳細図解

### ステップ1: 📂 作業場所の準備

```mermaid
graph LR
    A[スクリプトが起動] --> B{リポジトリは<br/>存在する?}
    B -->|Yes| C[そこに移動<br/>cd /Users/yuasys/.../chatty-journal]
    B -->|No| D[エラー表示して終了]
    
    style C fill:#90EE90
    style D fill:#FFB6C1
```

**対応するコード**:
```bash
# 基本設定
REPO_ROOT="/Users/yuasys/source/chatty-journal"

# ディレクトリ移動
if [[ -d "$REPO_ROOT" ]]; then
    cd "$REPO_ROOT" || { echo "Failed to enter $REPO_ROOT"; exit 1; }
else
    echo "Repository directory not found: $REPO_ROOT"
    exit 1
fi
```

**なぜ必要?**  
cronや自動実行ツールから呼び出された場合、「今どこのフォルダにいるか」が保証されません。
例えば、ホームディレクトリ (`~`) にいる状態で実行されると、ファイル作成先がずれてしまいます。

**実行例**:
```bash
# 悪い例（どこにいるか不明）
$ pwd
/Users/yuasys/Desktop
$ ./daily-journal.sh  # ← ここで実行するとファイルがDesktopに作られてしまう！

# 良い例（スクリプトが自動で正しい場所へ移動）
$ ./daily-journal.sh
Found latest entry: 2026-01-30. Creating entry for: 2026-01-31
```

---

### ステップ2: 📅 日付の自動計算

```mermaid
flowchart TD
    A[既存ファイルを検索] --> B{最新ファイルが<br/>見つかった?}
    
    B -->|Yes| C[2026-01-30.md<br/>が見つかった！]
    B -->|No| D[何もない<br/>初回実行]
    
    C --> E[翌日を計算<br/>2026-01-30 + 1日<br/>= 2026-01-31]
    D --> F[今日の日付を使う<br/>システム日付]
    
    E --> G[TODAY_YMD に保存]
    F --> G
    
    G --> H[ヘッダー用に変換<br/>2026年01月31日月]
    
    style C fill:#B3E5FC
    style E fill:#FFECB3
    style G fill:#C5E1A5
    style H fill:#F8BBD0
```

**対応するコード**:
```bash
# すべての日誌ファイルを検索 (形式: YYYY/MM/YYYY-MM-DD.md)
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
```

**ポイント**:
- 「最新ファイルの翌日」を自動計算 → 連続した日付で作成できる
- 例: 1/25に書き忘れても、1/26に実行すれば1/26分が作られる

**具体的な動作例**:

| 既存ファイル | 実行日 | 作成される日付 | 備考 |
|---|---|---|---|
| 2026-01-30.md | 1/31 | 2026-01-31.md | ✅ 正常（翌日） |
| 2026-01-28.md | 1/31 | 2026-01-29.md | ✅ 飛び飛びでもOK（2日前の続き） |
| なし | 1/31 | 2026-01-31.md | ✅ 初回（今日の日付） |

---

### ステップ3: 🔗 リンクURLの準備

日誌ファイルには「前後の日へのリンク」が必要。事前に計算しておく。

```mermaid
graph TD
    TODAY[今日<br/>2026-01-31]
    
    TODAY --> PREV[前日を計算<br/>2026-01-30]
    TODAY --> NEXT[翌日を計算<br/>2026-02-01]
    
    PREV --> URL1[URL生成<br/>https://github.com/.../2026/01/2026-01-30.md]
    NEXT --> URL2[URL生成<br/>https://github.com/.../2026/02/2026-02-01.md]
    
    style TODAY fill:#FFD54F
    style PREV fill:#81C784
    style NEXT fill:#64B5F6
```

**対応するコード**:
```bash
# 前日と翌日の日付計算（ナビゲーション用）
YESTERDAY_YMD=$(date -j -v-1d -f "%Y-%m-%d" "$TODAY_YMD" "+%Y-%m-%d")
TOMORROW_YMD=$(date -j -v+1d -f "%Y-%m-%d" "$TODAY_YMD" "+%Y-%m-%d")

# リンク用パスの生成
PREV_DAY_LINK="${URL_BASE}/${YESTERDAY_YMD:0:4}/${YESTERDAY_YMD:5:2}/${YESTERDAY_YMD}.md"
NEXT_DAY_LINK="${URL_BASE}/${TOMORROW_YMD:0:4}/${TOMORROW_YMD:5:2}/${TOMORROW_YMD}.md"
```

**変数展開の仕組み**:
```bash
# 例: TODAY_YMD = "2026-01-31" の場合
${TODAY_YMD:0:4}  # → "2026" (0番目から4文字)
${TODAY_YMD:5:2}  # → "01"   (5番目から2文字)
```

---

### ステップ4: 🔍 前の記事を探す（最重要ロジック）

> [!IMPORTANT]
> 「前日」と「前の記事」は違う！空の日があるかもしれないから、**実際に中身がある記事**を探す。

```mermaid
flowchart TD
    Start[全てのmdファイルをスキャン] --> Filter1{指定日より<br/>新しい?}
    
    Filter1 -->|古すぎる| Skip1[スキップ]
    Filter1 -->|OK| Filter2{今日より<br/>前?}
    
    Filter2 -->|未来| Skip2[スキップ]
    Filter2 -->|OK| Check[中身チェック]
    
    Check --> Dash{3つ以上の<br/>--- がある?}
    
    Dash -->|No| Skip3[スキップ]
    Dash -->|Yes| Count{本文が<br/>3行以上?}
    
    Count -->|No| Skip4[空ファイル<br/>スキップ]
    Count -->|Yes| Valid[有効なファイル！<br/>リストに追加]
    
    Valid --> Sort[リストをソート]
    Sort --> Last[最後の1つを選択<br/>= 直近の有効記事]
    
    style Valid fill:#81C784
    style Last fill:#FFD54F
```

**対応するコード**:
```bash
setopt extended_glob
matched_files=()
MIN_DATE_FILE="2025-04-08.md"

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

**具体例で理解する**:

仮に以下のファイルがあるとします:

```
2026-01-28.md  ← 📝 本文あり（500文字）
2026-01-29.md  ← 🈳 空ファイル（タイトルのみ）
2026-01-30.md  ← 📝 本文あり（300文字）
```

スクリプトが `2026-01-31.md` を作成する際:

1. **2026-01-28.md** → ✅ 有効（リストに追加）
2. **2026-01-29.md** → ❌ 空なのでスキップ
3. **2026-01-30.md** → ✅ 有効（リストに追加）

最終的に **2026-01-30.md** が選ばれる（最新だから）。

→ **「前の記事へ」のリンク先** = `2026-01-30.md`

---

### ステップ5: 📝 ファイル生成

テンプレートに、計算した値を埋め込んでファイルを作成。

```mermaid
graph TD
    A[テンプレート準備] --> B[変数を埋め込む]
    
    B --> C[HEADER_DATE<br/>→ 2026年01月31日月]
    B --> D[PREV_DAY_LINK<br/>→ 前日へのURL]
    B --> E[NEXT_DAY_LINK<br/>→ 翌日へのURL]
    B --> F[PREV_ARTICLE_LINK<br/>→ 前の記事URL]
    B --> G[NEXT_ARTICLE_LINK<br/>→ 次の記事URL]
    
    C --> H[cat EOF でファイル書き込み]
    D --> H
    E --> H
    F --> H
    G --> H
    
    H --> I[2026/01/2026-01-31.md<br/>完成！]
    
    style I fill:#4CAF50,color:#FFF
```

**対応するコード**:
```bash
TARGET_FILE="${TODAY_YEAR}/${TODAY_MONTH}/${TODAY_YMD}.md"
mkdir -p "${TODAY_YEAR}/${TODAY_MONTH}"

cat <<EOF > "$TARGET_FILE"

# ${HEADER_DATE}

---

### [◀️前日へ](${PREV_DAY_LINK})    [翌日へ▶️](${NEXT_DAY_LINK})

---

---

### [◀️前の記事へ](${PREV_ARTICLE_LINK})    [次の記事へ▶️](${NEXT_ARTICLE_LINK})

EOF
```

**ヒアドキュメント (`cat <<EOF`) の仕組み**:

```bash
# 通常の書き方（面倒）
echo "# タイトル" > file.md
echo "" >> file.md
echo "本文" >> file.md

# ヒアドキュメント（楽）
cat <<EOF > file.md
# タイトル

本文
EOF
```

変数 `${VAR}` も自動で展開されるので便利！

---

### ステップ6: 💾 Git自動保存

作成したファイルをGitHubへ自動でアップロード。

```mermaid
sequenceDiagram
    participant Script as スクリプト
    participant Local as ローカルリポジトリ
    participant Remote as GitHub

    Script->>Remote: git pull origin main<br/>(最新を取得)
    Remote-->>Local: 更新データ
    
    Script->>Local: git add .<br/>(新ファイルをステージング)
    Script->>Local: git commit -m "Add journal..."<br/>(コミット)
    
    Script->>Remote: git push origin main<br/>(アップロード)
    Remote-->>Script: ✅ 完了
```

**対応するコード**:
```bash
echo "Executing Git Operations..."
git pull origin main
git add .
git commit -m "Add journal for ${TODAY_YMD}"
git push origin main
```

**なぜ `git pull` が最初?**  
他のデバイス（例: スマホ）で編集した内容と衝突しないように、最新版を取得してから作業します。

---

## まとめ: スクリプト全体のデータフロー

```mermaid
graph TB
    subgraph Input[入力]
        I1[既存ファイル群]
        I2[システム日付]
    end
    
    subgraph Process[処理]
        P1[日付計算エンジン]
        P2[ファイル検索エンジン]
        P3[テンプレート生成エンジン]
    end
    
    subgraph Output[出力]
        O1[新しいmdファイル]
        O2[GitHubへ同期]
    end
    
    I1 --> P1
    I2 --> P1
    P1 --> P2
    P2 --> P3
    P3 --> O1
    O1 --> O2
    
    style Input fill:#E3F2FD
    style Process fill:#FFF3E0
    style Output fill:#E8F5E9
```

---

## 初心者向けQ&A

### Q1: なぜfindコマンドを使うの？
**A**: 大量のファイルから特定のパターン（YYYY-MM-DD.md）を高速に探すため。
```bash
# 手動で探すのは大変...
ls 2022/01/*.md 2022/02/*.md ... 2026/12/*.md

# findなら一発！
find . -name "*.md"
```

### Q2: `setopt extended_glob` って何？
**A**: zshの高度なファイル名マッチング機能を有効化するおまじない。
```bash
# これが使えるようになる
./**/[0-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9].md(N)
#    ↑再帰検索  ↑数字パターン                        ↑エラー抑制
```

### Q3: `cat <<EOF` の意味は？
**A**: 「ヒアドキュメント」という技法。複数行のテキストをそのままファイルに書き込める便利な書き方。

### Q4: `${変数:開始:長さ}` って何？
**A**: 文字列の一部を切り出す記法（部分文字列抽出）。
```bash
DATE="2026-01-31"
echo ${DATE:0:4}  # → "2026"
echo ${DATE:5:2}  # → "01"
echo ${DATE:8:2}  # → "31"
```

### Q5: `|| continue` の意味は？
**A**: 「もしエラーなら次へスキップ」という意味。
```bash
[[ "$filename" < "$MIN_DATE_FILE" ]] && continue
# ↑この条件が真なら、continueが実行され、ループの次へ
```

---

## トラブルシューティング

### ❌ エラー: `Repository directory not found`

**原因**: `REPO_ROOT` のパスが間違っている。

**解決策**:
```bash
# スクリプトの7-8行目を確認
REPO_ROOT="/Users/yuasys/source/chatty-journal"  # ← ここを自分の環境に合わせる
```

実際のパスを確認:
```bash
$ cd ~/chatty-journal  # 実際のリポジトリへ移動
$ pwd                   # 絶対パスを表示
/Users/yuasys/source/chatty-journal  # ← この値をコピー
```

---

### ❌ エラー: `permission denied`

**原因**: スクリプトに実行権限がない。

**解決策**:
```bash
chmod +x daily-journal.sh
```

確認:
```bash
$ ls -l daily-journal.sh
-rwxr-xr-x  1 yuasys  staff  4567 Jan 31 10:00 daily-journal.sh
 ↑ この「x」が実行権限
```

---

### ❌ エラー: `git push` が失敗する

**原因**: Git認証の問題、またはネットワークエラー。

**解決策**:
```bash
# 1. Git認証を確認
git config --global user.name
git config --global user.email

# 2. SSH鍵が設定されているか確認
ssh -T git@github.com

# 3. 手動でpushできるか試す
git push origin main
```

---

### ⚠️ 注意: 同じ日を2回実行すると?

**結果**: 上書きされます（警告メッセージ表示）。

```bash
$ ./daily-journal.sh
File 2026/01/2026-01-31.md already exists. Overwriting...
```

意図的に再作成したい場合以外は、重複実行に注意！

---

## ハンズオン練習

### 練習1: スクリプトを実行してみよう

```bash
# 1. スクリプトのあるディレクトリへ移動
cd /Users/yuasys/source/chatty-journal

# 2. 実行権限を付与（初回のみ）
chmod +x daily-journal.sh

# 3. 実行！
./daily-journal.sh
```

**期待される出力**:
```
Found latest entry: 2026-01-30. Creating entry for: 2026-01-31
Previous Valid Article: ./2026/01/2026-01-30.md
Next Valid Article:     
Created journal entry: 2026/01/2026-01-31.md
Executing Git Operations...
...
```

---

### 練習2: 作成されたファイルを確認しよう

```bash
# ファイルが作られたか確認
ls -l 2026/01/2026-01-31.md

# 中身を見る
cat 2026/01/2026-01-31.md
```

---

### 練習3: 変数の中身を確認してみよう

スクリプトの途中に `echo` を追加して、デバッグしてみましょう:

```bash
# 例: 日付計算の結果を確認
TODAY_YMD=$(date -j -v+1d -f "%Y-%m-%d" "$LATEST_DATE" "+%Y-%m-%d")
echo "DEBUG: TODAY_YMD = $TODAY_YMD"  # ← この行を追加
```

---

## さらに学ぶために

このスクリプトを理解したら、次のステップへ:

1. **cronで自動化**: 毎日決まった時間に自動実行
2. **テンプレートのカスタマイズ**: 自分好みの日誌フォーマットに変更
3. **他のスクリプトとの連携**: 天気情報やタスク一覧を自動挿入

---

**このスクリプトを理解できれば、自動化の基礎が身につきます！** 🎉
