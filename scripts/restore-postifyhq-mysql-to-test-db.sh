#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 /path/to/backup.sql" >&2
  exit 1
fi

BACKUP_FILE="$1"

NAMESPACE="${NAMESPACE:-postifyhq}"
POD="${POD:-postifyhq-mysql-0}"
CONTAINER="${CONTAINER:-mysql}"
SOURCE_DB="${SOURCE_DB:-postifyhq}"
RESTORE_DB="${RESTORE_DB:-postifyhq_restore_test}"
CLEANUP="${CLEANUP:-true}"

if [ ! -s "$BACKUP_FILE" ]; then
  echo "ERROR: Backup file does not exist or is empty: $BACKUP_FILE" >&2
  exit 1
fi

mysql_exec() {
  local sql="$1"
  printf '%s\n' "$sql" | kubectl exec -i -n "$NAMESPACE" "$POD" -c "$CONTAINER" -- \
    sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot'
}

mysql_exec_raw() {
  local sql="$1"
  printf '%s\n' "$sql" | kubectl exec -i -n "$NAMESPACE" "$POD" -c "$CONTAINER" -- \
    sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -N'
}

cleanup_restore_db() {
  if [ "$CLEANUP" = "true" ]; then
    echo "Cleaning up restore-test database..."
    mysql_exec "DROP DATABASE IF EXISTS \`$RESTORE_DB\`;"
    echo "Cleanup completed."
  else
    echo "Cleanup skipped. Restore-test DB remains: $RESTORE_DB"
  fi
}

trap 'echo "Restore test failed. Cleaning up restore-test database..."; mysql_exec "DROP DATABASE IF EXISTS \`$RESTORE_DB\`;" >/dev/null 2>&1 || true' ERR

echo "Starting restore test..."
echo "Backup file: $BACKUP_FILE"
echo "Source DB: $SOURCE_DB"
echo "Restore-test DB: $RESTORE_DB"

echo "Recreating restore-test database..."
mysql_exec "DROP DATABASE IF EXISTS \`$RESTORE_DB\`; CREATE DATABASE \`$RESTORE_DB\`;"

echo "Restoring backup into restore-test database..."
cat "$BACKUP_FILE" | kubectl exec -i -n "$NAMESPACE" "$POD" -c "$CONTAINER" -- \
  sh -c "MYSQL_PWD=\"\$MYSQL_ROOT_PASSWORD\" mysql -uroot \"$RESTORE_DB\""

echo "Comparing table counts..."
SOURCE_TABLE_COUNT="$(mysql_exec_raw "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$SOURCE_DB';" | tr -d '[:space:]')"
RESTORE_TABLE_COUNT="$(mysql_exec_raw "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$RESTORE_DB';" | tr -d '[:space:]')"

echo "Source table count: $SOURCE_TABLE_COUNT"
echo "Restore table count: $RESTORE_TABLE_COUNT"

if [ "$SOURCE_TABLE_COUNT" != "$RESTORE_TABLE_COUNT" ]; then
  echo "ERROR: Table count mismatch." >&2
  exit 1
fi

echo "Comparing table checksums..."
TABLES="$(mysql_exec_raw "SELECT table_name FROM information_schema.tables WHERE table_schema = '$SOURCE_DB' AND table_type = 'BASE TABLE';")"

for TABLE in $TABLES; do
  SOURCE_CHECKSUM="$(mysql_exec_raw "CHECKSUM TABLE \`$SOURCE_DB\`.\`$TABLE\`;" | awk '{print $2}')"
  RESTORE_CHECKSUM="$(mysql_exec_raw "CHECKSUM TABLE \`$RESTORE_DB\`.\`$TABLE\`;" | awk '{print $2}')"

  echo "$TABLE: source=$SOURCE_CHECKSUM restore=$RESTORE_CHECKSUM"

  if [ "$SOURCE_CHECKSUM" != "$RESTORE_CHECKSUM" ]; then
    echo "ERROR: Checksum mismatch for table: $TABLE" >&2
    exit 1
  fi
done

echo "Restore verification succeeded."

trap - ERR
cleanup_restore_db
