#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESTORE="$ROOT/Sources/TextFlash/Resources/Tools/textflash-restore.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

make_database() {
    local path="$1"
    local value="$2"
    sqlite3 "$path" <<SQL
CREATE TABLE groups (id TEXT PRIMARY KEY, name TEXT NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0);
CREATE TABLE snippets (id TEXT PRIMARY KEY, group_id TEXT NOT NULL, abbreviation TEXT NOT NULL, expanded_text TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', sort_order INTEGER NOT NULL DEFAULT 0);
INSERT INTO groups VALUES ('group-id', '$value', 0);
SQL
}

run_restore() {
    TEXTFLASH_DATA_DIR="$1" PATH="$TEST_ROOT/bin:$PATH" "$RESTORE" "$2"
}

mkdir -p "$TEST_ROOT/bin"
for command in osascript sleep open killall defaults; do
    printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/bin/$command"
    chmod +x "$TEST_ROOT/bin/$command"
done
printf '#!/bin/sh\nexit 1\n' > "$TEST_ROOT/bin/pgrep"
chmod +x "$TEST_ROOT/bin/pgrep"

# 应用退出请求失败时不得写入数据库。
data="$TEST_ROOT/quit-data"
backup="$TEST_ROOT/quit-backup"
mkdir -p "$data" "$backup"
make_database "$data/textflash.db" original
make_database "$backup/textflash.db" replacement
printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/bin/pgrep"
printf '#!/bin/sh\nexit 1\n' > "$TEST_ROOT/bin/osascript"
if run_restore "$data" "$backup" >/dev/null 2>&1; then
    echo "quit failure unexpectedly succeeded" >&2
    exit 1
fi
[ "$(sqlite3 "$data/textflash.db" 'SELECT name FROM groups;')" = original ]
printf '#!/bin/sh\nexit 1\n' > "$TEST_ROOT/bin/pgrep"
printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/bin/osascript"

# 损坏备份不得替换现有数据库。
data="$TEST_ROOT/damaged-data"
backup="$TEST_ROOT/damaged-backup"
mkdir -p "$data" "$backup"
make_database "$data/textflash.db" original
printf 'not a SQLite database\n' > "$backup/textflash.db"
if run_restore "$data" "$backup" >/dev/null 2>&1; then
    echo "damaged backup unexpectedly succeeded" >&2
    exit 1
fi
[ "$(sqlite3 "$data/textflash.db" 'SELECT name FROM groups;')" = original ]

# 崩溃遗留 WAL 中已提交的数据必须进入保护性快照。
data="$TEST_ROOT/wal-data"
backup="$TEST_ROOT/wal-backup"
mkdir -p "$data" "$backup"
make_database "$data/textflash.db" before-wal
make_database "$backup/textflash.db" replacement
python3 - "$data/textflash.db" <<'PY'
import os, sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.execute("PRAGMA journal_mode=WAL")
db.execute("PRAGMA wal_autocheckpoint=0")
db.execute("UPDATE groups SET name='committed-in-wal'")
db.commit()
os._exit(0)
PY
run_restore "$data" "$backup" >/dev/null
protection="$(find "$data" -name 'textflash.db.before-restore.*' -print -quit)"
[ -n "$protection" ]
[ "$(sqlite3 "$protection" 'SELECT name FROM groups;')" = committed-in-wal ]
[ "$(sqlite3 "$data/textflash.db" 'SELECT name FROM groups;')" = replacement ]

# 偏好导入失败必须非零退出并准确说明数据库已恢复。
printf '#!/bin/sh\nexit 1\n' > "$TEST_ROOT/bin/defaults"
chmod +x "$TEST_ROOT/bin/defaults"
printf 'plist\n' > "$backup/preferences.plist"
if output="$(run_restore "$data" "$backup" 2>&1)"; then
    echo "preferences failure unexpectedly succeeded" >&2
    exit 1
fi
case "$output" in
    *"Restored database, but preferences import failed (partial restore)"*) ;;
    *) echo "preferences failure was not reported accurately" >&2; exit 1 ;;
esac

echo "restore behavior tests passed"
