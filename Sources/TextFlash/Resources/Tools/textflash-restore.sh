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
DB_PATH="$DATA_DIR/textflash.db"

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
    cp "$DB_PATH" "$DB_PATH.before-restore"
fi
tmp_db="$(mktemp "$DATA_DIR/textflash.db.restore.XXXXXX")"
trap 'rm -f "$tmp_db"' EXIT
cp "$DB_BACKUP" "$tmp_db"
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
