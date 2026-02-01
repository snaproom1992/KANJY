#!/bin/bash

# Supabaseイベントデータのバックアップスクリプト
# 使い方: ./backup-supabase-events.sh

set -e

# Supabase認証情報（環境変数から読み込むか、ここに直接記載）
SUPABASE_URL="${SUPABASE_URL:-https://jvluhjifihiuopqdwjll.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2bHVoamlmaWhpdW9wcWR3amxsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExNTc5OTEsImV4cCI6MjA2NjczMzk5MX0.WDTzIs73X8NHGFcIYFk4CN-7dH5tQT5l0Bd2uY6H9lc}"

# バックアップディレクトリ
BACKUP_DIR="${HOME}/Desktop/ios_KanjyApp/.agent/backups"
mkdir -p "$BACKUP_DIR"

# タイムスタンプ
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="$BACKUP_DIR/supabase_events_$TIMESTAMP.json"
CSV_FILE="$BACKUP_DIR/supabase_events_$TIMESTAMP.csv"

echo "🔍 Supabaseからイベントデータを取得中..."

# JSONデータを取得
curl -s -X GET \
  "$SUPABASE_URL/rest/v1/events?select=*&order=created_at.desc" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  > "$BACKUP_FILE"

# イベント数を確認
EVENT_COUNT=$(cat "$BACKUP_FILE" | jq '. | length')

if [ "$EVENT_COUNT" -eq 0 ]; then
  echo "⚠️  バックアップするイベントがありません"
  rm "$BACKUP_FILE"
  exit 0
fi

echo "📊 $EVENT_COUNT 件のイベントを取得しました"

# JSONをCSVに変換（jqを使用）
echo "💾 CSVに変換中..."

cat "$BACKUP_FILE" | jq -r '
  (.[0] | keys_unsorted) as $keys |
  $keys,
  (.[] | [.[ $keys[] ]]) |
  @csv
' > "$CSV_FILE"

echo "✅ バックアップ完了!"
echo "   JSON: $BACKUP_FILE"
echo "   CSV:  $CSV_FILE"

# サマリー表示
echo ""
echo "📋 データサマリー:"
cat "$BACKUP_FILE" | jq -r '.[] | "\(.title) (作成日: \(.created_at))"' | head -5
if [ "$EVENT_COUNT" -gt 5 ]; then
  echo "   ... 他 $((EVENT_COUNT - 5)) 件"
fi
