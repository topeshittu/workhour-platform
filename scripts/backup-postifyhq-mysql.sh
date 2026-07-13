#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-postifyhq}"
POD="${POD:-postifyhq-mysql-0}"
CONTAINER="${CONTAINER:-mysql}"
DB_NAME="${DB_NAME:-postifyhq}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/postifyhq-mysql-backups}"

mkdir -p "$BACKUP_DIR"

BACKUP_FILE="$BACKUP_DIR/${DB_NAME}-mysql-$(date +%Y%m%d-%H%M%S).sql"

echo "Creating MySQL backup..."
echo "Namespace: $NAMESPACE"
echo "Pod: $POD"
echo "Container: $CONTAINER"
echo "Database: $DB_NAME"
echo "Backup file: $BACKUP_FILE"

kubectl exec -n "$NAMESPACE" "$POD" -c "$CONTAINER" -- \
  sh -c "MYSQL_PWD=\"\$MYSQL_ROOT_PASSWORD\" mysqldump -uroot --single-transaction --routines --triggers $DB_NAME" \
  > "$BACKUP_FILE"

if [ ! -s "$BACKUP_FILE" ]; then
  echo "ERROR: Backup file was created but is empty: $BACKUP_FILE" >&2
  exit 1
fi

if ! grep -q "CREATE TABLE" "$BACKUP_FILE"; then
  echo "WARNING: Backup file does not contain CREATE TABLE statements." >&2
fi

echo "Backup created successfully."
ls -lh "$BACKUP_FILE"
echo "$BACKUP_FILE"
