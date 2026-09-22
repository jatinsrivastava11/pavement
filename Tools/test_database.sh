#!/bin/zsh
# Runs every Supabase migration and the behavior test against a throwaway local Postgres.
# Needs Postgres binaries: PG_BIN=/path/to/postgres/bin Tools/test_database.sh
# (e.g. from the free Postgres.app download, no install needed: mount the .dmg and point PG_BIN
# at Postgres.app/Contents/Versions/17/bin).
root=$(cd "$(dirname $0)/.." && pwd)
PG_BIN=${PG_BIN:?set PG_BIN to a Postgres bin directory}
work=$(mktemp -d /tmp/pavement-db.XXXX)

cleanup() {
  # Stop the server even if a check failed, then delete the throwaway database.
  "$PG_BIN/pg_ctl" -D "$work/data" stop -m immediate >/dev/null 2>&1
  rm -rf "$work"
}
fail() { echo "FAILED: $1"; cleanup; exit 1; }
psqlq() { "$PG_BIN/psql" -h localhost -p 54329 -U postgres -v ON_ERROR_STOP=1 -q "$@"; }

"$PG_BIN/initdb" -D "$work/data" -U postgres -A trust >/dev/null || fail "initdb"
"$PG_BIN/pg_ctl" -D "$work/data" -o "-p 54329 -c listen_addresses=localhost -c unix_socket_directories=''" \
  -l "$work/pg.log" -w start >/dev/null || fail "server didn't start (is port 54329 free?)"
psqlq -c "create database pavement" || fail "create database"
psqlq -d pavement -f "$root/supabase/tests/supabase_stub.sql" || fail "Supabase stand-in"
for f in "$root"/supabase/migrations/*.sql; do
  echo "applying $(basename $f)"
  psqlq -d pavement -f "$f" || fail "migration $(basename $f)"
done
psqlq -d pavement -f "$root/supabase/tests/behavior_test.sql" || fail "behavior test"
cleanup
