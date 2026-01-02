#!/bin/zsh

# 1. 日付変数の設定 (macOS用 dateコマンド)
TODAY=$(date "+%Y-%m-%d")
YEAR=$(date "+%Y")
MONTH=$(date "+%m")
TARGET_DIR="$YEAR/$MONTH"

YESTERDAY_STR=$(date -v-1d "+%Y/%m/%Y-%m-%d.md")
TOMORROW_STR=$(date -v+1d "+%Y/%m/%Y-%m-%d.md")

# 変数の内容を表示(デバック用）
echo "TODAY = \"$TODAY\""
echo "YEAR = \"$YEAR\""
echo "MONTH = \"$MONTH\""
echo "TARGET_DIR = \"$TARGET_DIR\""
echo "YESTERDAY_STR = \"$YESTERDAY_STR\""
echo "TOMORROW_STR = \"$TOMORROW_STR\""

# 2. 「前の記事」のURLを特定 (既存のmdファイルから最新のものを検索)
