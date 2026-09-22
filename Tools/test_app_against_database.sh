#!/bin/zsh
# End-to-end test of the app's database code against the real migrations, with no Supabase account:
# local Postgres + PostgREST + a small proxy, then the app's own queries from the test suite.
#
#   PG_BIN=/path/to/postgres/bin POSTGREST=/path/to/postgrest Tools/test_app_against_database.sh
root=$(cd "$(dirname $0)/.." && pwd)
PG_BIN=${PG_BIN:?set PG_BIN to a Postgres bin directory}
POSTGREST=${POSTGREST:?set POSTGREST to the postgrest binary}
DYLD_FALLBACK_LIBRARY_PATH=${DYLD_FALLBACK_LIBRARY_PATH:-$PG_BIN/../lib}
export DYLD_FALLBACK_LIBRARY_PATH
work=$(mktemp -d /tmp/pavement-e2e.XXXX)
secret="pavement-local-test-secret-key-32-chars-plus"
ana="00000000-0000-0000-0000-00000000000a"
bo="00000000-0000-0000-0000-00000000000b"

cleanup() {
  [[ -n "$proxy_pid" ]] && kill $proxy_pid 2>/dev/null
  [[ -n "$rest_pid" ]] && kill $rest_pid 2>/dev/null
  "$PG_BIN/pg_ctl" -D "$work/data" stop -m immediate >/dev/null 2>&1
  rm -rf "$work"
}
fail() { echo "FAILED: $1"; exit 1; }
trap cleanup EXIT INT TERM    # always stop the servers, whatever goes wrong
psqlq() { "$PG_BIN/psql" -h localhost -p 54330 -U postgres -v ON_ERROR_STOP=1 -q "$@"; }

"$PG_BIN/initdb" -D "$work/data" -U postgres -A trust >/dev/null || fail "initdb"
"$PG_BIN/pg_ctl" -D "$work/data" -o "-p 54330 -c listen_addresses=localhost -c unix_socket_directories=''" \
  -l "$work/pg.log" -w start >/dev/null || fail "server didn't start (is port 54330 free?)"
psqlq -c "create database pavement" || fail "create database"
psqlq -d pavement -f "$root/supabase/tests/supabase_stub.sql" || fail "Supabase stand-in"
for f in "$root"/supabase/migrations/*.sql; do psqlq -d pavement -f "$f" || fail "migration $(basename $f)"; done
psqlq -d pavement -c "insert into auth.users (id, email) values ('$ana', 'ana@test.invalid'), ('$bo', 'bo@test.invalid')" || fail "seed users"

PGRST_DB_URI="postgres://authenticator:pavement-test@localhost:54330/pavement" \
PGRST_DB_SCHEMAS="public" PGRST_DB_ANON_ROLE="anon" PGRST_JWT_SECRET="$secret" \
PGRST_SERVER_PORT=3010 PGRST_LOG_LEVEL=error "$POSTGREST" > "$work/postgrest.log" 2>&1 < /dev/null &
rest_pid=$!
python3 "$root/Tools/rest_proxy.py" 3011 3010 > "$work/proxy.log" 2>&1 & proxy_pid=$!
for i in {1..40}; do curl -s -o /dev/null "http://127.0.0.1:3011/rest/v1/" && break; sleep 0.5; done

export TEST_RUNNER_PAVEMENT_DB_URL="http://127.0.0.1:3011"
export TEST_RUNNER_PAVEMENT_ANA_ID=$ana TEST_RUNNER_PAVEMENT_BO_ID=$bo
TEST_RUNNER_PAVEMENT_ANA_JWT=$(python3 "$root/Tools/mint_jwt.py" "$secret" "$ana") || fail "mint token"
TEST_RUNNER_PAVEMENT_BO_JWT=$(python3 "$root/Tools/mint_jwt.py" "$secret" "$bo") || fail "mint token"
export TEST_RUNNER_PAVEMENT_ANA_JWT TEST_RUNNER_PAVEMENT_BO_JWT

bundle_args=()
[[ -n "$RESULT_BUNDLE" ]] && { rm -rf "$RESULT_BUNDLE"; bundle_args=(-resultBundlePath "$RESULT_BUNDLE") }
xcodebuild test -project "$root/Pavement.xcodeproj" -scheme Pavement \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:PavementTests/SupabaseIntegrationTests \
  -derivedDataPath "${DERIVED_DATA:-$work/dd}" $bundle_args 2>&1 | grep -E "Test case|TEST (SUCCEEDED|FAILED)|error:" | tail -20
result=$pipestatus[1]
cleanup
exit $result
