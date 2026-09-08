#!/bin/bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  textflash-restore.sh [--launch] backup-dir

Restores a TextFlash backup created by textflash-backup.sh.
Use --launch to reopen TextFlash after restoring.
USAGE
}

LAUNCH_AFTER_RESTORE=false
if [ "${1:-}" = "--launch" ]; then
    LAUNCH_AFTER_RESTORE=true
    shift
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ $# -ne 1 ]; then
    usage
    exit 0
fi

BACKUP_DIR="$1"
DB_BACKUP="$BACKUP_DIR/textflash.db"
PREFS_BACKUP="$BACKUP_DIR/preferences.plist"

if [ ! -f "$DB_BACKUP" ]; then
    echo "Backup database not found: $DB_BACKUP" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
find_app_contents_dir() {
    local dir="$SCRIPT_DIR"
    while [ "$dir" != "/" ]; do
        if [ "$(basename "$dir")" = "Contents" ] && [ -f "$dir/Info.plist" ] && [[ "$(dirname "$dir")" == *.app ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    cd "$SCRIPT_DIR/../.." && pwd
}

CONTENTS_DIR="$(find_app_contents_dir)"
APP_DIR="$(cd "$CONTENTS_DIR/.." && pwd)"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST" 2>/dev/null || echo "com.nekutai.textflash")"

DATA_DIR="$HOME/Library/Application Support/TextFlash"
if [ -n "${TEXTFLASH_DATA_DIR:-}" ]; then
    DATA_DIR="$TEXTFLASH_DATA_DIR"
fi
DB_PATH="$DATA_DIR/textflash.db"

if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "sqlite3 is required to validate and restore a database backup." >&2
    exit 1
fi

validate_database() {
    local candidate="$1"
    [ "$(sqlite3 "$candidate" 'PRAGMA integrity_check;' 2>/dev/null)" = "ok" ] || return 1
    [ "$(sqlite3 "$candidate" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name IN ('groups','snippets');" 2>/dev/null)" = "2" ] || return 1
    [ "$(sqlite3 "$candidate" "SELECT count(*) FROM pragma_table_info('groups') WHERE name IN ('id','name','sort_order');" 2>/dev/null)" = "3" ] || return 1
    [ "$(sqlite3 "$candidate" "SELECT count(*) FROM pragma_table_info('snippets') WHERE name IN ('id','group_id','abbreviation','expanded_text','description','sort_order');" 2>/dev/null)" = "6" ] || return 1
}

if ! validate_database "$DB_BACKUP"; then
    echo "Restore aborted: backup is not a valid TextFlash database" >&2
    exit 1
fi

if pgrep -x TextFlash >/dev/null 2>&1; then
    if ! osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1; then
        echo "Restore aborted: TextFlash is running and could not be asked to quit" >&2
        exit 1
    fi
    for _ in $(seq 1 30); do
        pgrep -x TextFlash >/dev/null 2>&1 || break
        sleep 1
    done
    if pgrep -x TextFlash >/dev/null 2>&1; then
        echo "Restore aborted: TextFlash did not quit before timeout" >&2
        exit 1
    fi
fi

mkdir -p "$DATA_DIR"
if [ -f "$DB_PATH" ]; then
    stamp="$(date +%Y%m%d-%H%M%S)"
    protection_path="$DB_PATH.before-restore.$stamp"
    suffix=0
    while [ -e "$protection_path" ]; do
        suffix=$((suffix + 1))
        protection_path="$DB_PATH.before-restore.$stamp.$suffix"
    done
    if ! sqlite3 "$DB_PATH" ".backup '$protection_path'"; then
        echo "Restore aborted: could not create a consistent protection backup" >&2
        exit 1
    fi
fi
tmp_db="$(mktemp "$DATA_DIR/textflash.db.restore.XXXXXX")"
trap 'rm -f "$tmp_db"' EXIT
cp "$DB_BACKUP" "$tmp_db"
if ! validate_database "$tmp_db"; then
    echo "Restore aborted: staged database validation failed" >&2
    exit 1
fi
mv "$tmp_db" "$DB_PATH"
rm -f "$DATA_DIR/textflash.db-wal" "$DATA_DIR/textflash.db-shm"

if [ -f "$PREFS_BACKUP" ] && [ -s "$PREFS_BACKUP" ]; then
    if ! defaults import "$BUNDLE_ID" "$PREFS_BACKUP" >/dev/null 2>&1; then
        echo "Restored database, but preferences import failed (partial restore)" >&2
        exit 1
    fi
    killall cfprefsd >/dev/null 2>&1 || true
fi

if $LAUNCH_AFTER_RESTORE; then
    open "$APP_DIR"
fi

echo "Restored TextFlash backup: $BACKUP_DIR"
