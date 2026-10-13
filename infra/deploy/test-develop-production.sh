#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
mkdir -p "$test_root/bin"
cat > "$test_root/bin/docker" <<'MOCK'
#!/bin/sh
printf 'docker %s\n' "$*" >> "$DEPLOY_TEST_LOG"
case "$*" in
  *'config --environment') printf 'CERTBOT_DOMAIN=418.buzz\n' ;;
  *' pull') test "${DEPLOY_TEST_PULL_FAIL:-0}" != 1 ;;
esac
MOCK
cat > "$test_root/bin/curl" <<'MOCK'
#!/bin/sh
printf 'curl %s\n' "$*" >> "$DEPLOY_TEST_LOG"
test "${DEPLOY_TEST_HEALTH_FAIL:-0}" != 1
MOCK
chmod +x "$test_root/bin/docker" "$test_root/bin/curl"
export PATH="$test_root/bin:$PATH"
sha=0123456789012345678901234567890123456789

setup_case() {
  case_dir="$test_root/$1"
  mkdir -p "$case_dir/letsencrypt/live/418.buzz"
  touch "$case_dir/.env"
  printf 'staging\n' > "$case_dir/.deployment-mode"
  printf 'certificate\n' > "$case_dir/letsencrypt/live/418.buzz/fullchain.pem"
  printf 'key\n' > "$case_dir/letsencrypt/live/418.buzz/privkey.pem"
  export DEPLOY_TEST_LOG="$case_dir/commands.log"
  : > "$DEPLOY_TEST_LOG"
}
run_deploy() {
  sh "$script_dir/develop-production.sh" "$case_dir" ghcr.io/test "$sha" > "$case_dir/output.log" 2>&1
}

setup_case missing-certificate
rm "$case_dir/letsencrypt/live/418.buzz/fullchain.pem"
if run_deploy; then echo 'Missing certificate must fail' >&2; exit 1; fi
test "$(cat "$case_dir/.deployment-mode")" = staging
! grep -qE ' (pull|down|up)( |$)' "$DEPLOY_TEST_LOG"

setup_case image-pull-failure
if DEPLOY_TEST_PULL_FAIL=1 run_deploy; then echo 'Image pull failure must fail' >&2; exit 1; fi
test "$(cat "$case_dir/.deployment-mode")" = staging
! grep -qE ' (down|up)( |$)' "$DEPLOY_TEST_LOG"

setup_case unknown-mode
printf 'maintenance\n' > "$case_dir/.deployment-mode"
if run_deploy; then echo 'Unknown mode must fail' >&2; exit 1; fi
test ! -s "$DEPLOY_TEST_LOG"

setup_case successful-migration
run_deploy
test "$(cat "$case_dir/.deployment-mode")" = production
test "$(cat "$case_dir/.production-image-tag")" = "$sha"
test "$(grep -c '^curl ' "$DEPLOY_TEST_LOG")" -eq 2
pull_line=$(grep -n ' pull$' "$DEPLOY_TEST_LOG" | cut -d: -f1)
down_line=$(grep -n ' down$' "$DEPLOY_TEST_LOG" | cut -d: -f1)
up_line=$(grep -n ' up ' "$DEPLOY_TEST_LOG" | cut -d: -f1)
test "$pull_line" -lt "$down_line" && test "$down_line" -lt "$up_line"
grep -q -- '--resolve 418.buzz:443:127.0.0.1 https://418.buzz/api/health' "$DEPLOY_TEST_LOG"

# Later develop pushes update the same production stack.
run_deploy
test "$(cat "$case_dir/.production-image-tag")" = "$sha"

setup_case failed-health-check
printf 'previous-successful-sha\n' > "$case_dir/.production-image-tag"
if DEPLOY_TEST_HEALTH_FAIL=1 run_deploy; then echo 'HTTPS failure must fail' >&2; exit 1; fi
test "$(cat "$case_dir/.production-image-tag")" = previous-successful-sha
echo 'Deployment tests passed (6 scenarios)'
