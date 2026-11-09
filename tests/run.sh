#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "Expected file not found: $1"
}

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || fail "Expected '$text' in $file"
}

for script in Backup/*.sh Upload/*.sh Dependencies/*.sh setup.sh update.sh; do
  bash -n "$script" || fail "Shell syntax check failed: $script"
done
echo "PASS: shell syntax"

setup_help=$(bash setup.sh --help)
[[ "$setup_help" == *"--status-detailed"* ]] || fail "setup.sh help is missing --status-detailed"
echo "PASS: setup help"

update_help=$(bash update.sh --help)
[[ "$update_help" == *"--main"* && "$update_help" == *"--v3"* && "$update_help" == *"--v2"* ]] ||
  fail "update.sh help is missing a supported branch option"
echo "PASS: update help"

if update_error=$(bash update.sh --invalid 2>&1); then
  fail "update.sh accepted an unknown argument"
fi
[[ "$update_error" == *"Unknown argument '--invalid'"* ]] ||
  fail "update.sh did not explain the invalid argument"
echo "PASS: update command line"

[[ "$EUID" -eq 0 ]] || fail "Integration tests must run as root (use sudo bash tests/run.sh)"
command -v gpg >/dev/null 2>&1 || fail "gpg is required for encryption integration tests"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

TEST_REPO="$TEST_ROOT/repo"
MOCK_BIN="$TEST_ROOT/mock-bin"
MOCK_LOG_DIR="$TEST_ROOT/mock-logs"
SYSTEMD_DIR="$TEST_ROOT/systemd"
GPG_PASS_FILE="$TEST_ROOT/gpg-pass"
BACKUP_DIR="$TEST_ROOT/backups"
STATUS_FILE="$TEST_ROOT/backup.status"
NAS_MOUNT="$TEST_ROOT/nas"
mkdir -p "$TEST_REPO" "$MOCK_BIN" "$MOCK_LOG_DIR" "$SYSTEMD_DIR" "$BACKUP_DIR" "$NAS_MOUNT"
cp -R Backup Configs Dependencies Upload setup.sh update.sh "$TEST_REPO/"

cat > "$MOCK_BIN/sudo" <<'MOCK'
#!/usr/bin/env bash
exec "$@"
MOCK

cat > "$MOCK_BIN/systemctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_LOG_DIR/systemctl.log"
exit 0
MOCK

cat > "$MOCK_BIN/curl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_LOG_DIR/curl.log"
for arg in "$@"; do
  if [[ "$arg" == "%{http_code}" ]]; then
    printf '%s' "${MOCK_HTTP_CODE:-201}"
  fi
done
exit "${MOCK_CURL_EXIT_CODE:-0}"
MOCK

cat > "$MOCK_BIN/aws" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_LOG_DIR/aws.log"
exit "${MOCK_AWS_EXIT_CODE:-0}"
MOCK

cat > "$MOCK_BIN/mountpoint" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod +x "$MOCK_BIN/"*

export PATH="$MOCK_BIN:$PATH"
export MOCK_LOG_DIR
export MAILCOW_GPG_PASS_FILE="$GPG_PASS_FILE"
export MAILCOW_SYSTEMD_UNIT_DIR="$SYSTEMD_DIR"
export MAILCOW_BACKUP_DIR="$BACKUP_DIR"
export MAILCOW_STATUS_FILE="$STATUS_FILE"
TEST_PASSPHRASE="mailcow-ci-test-passphrase"

setup_output=$(
  bash "$TEST_REPO/setup.sh" <<EOF
$TEST_PASSPHRASE
7
30
1,2,3,4
https://webdav.example.test/backups/
webdav-user
webdav-password
1
ftp.example.test
/backups
ftp-user
ftp-password
ftp-fingerprint
$NAS_MOUNT
/mailcow
test-bucket
mailcow
https://s3.example.test
TESTACCESSKEY
test-secret-key
eu-test-1
1
02:00
y
1
03:00
y
1
04:00
y
1
05:00
y
1
06:00
EOF
)
[[ "$setup_output" == *"Setup completed!"* ]] || fail "setup.sh did not complete"
[[ "$(stat -c '%a' "$GPG_PASS_FILE")" == "600" ]] || fail "GPG password file is not mode 600"
echo "PASS: setup and encrypted configuration creation"

for method in webdav ftp nas s3; do
  encrypted_config="$TEST_REPO/Configs/$method-config.sh.gpg"
  plaintext_config="$TEST_ROOT/$method-config.sh"
  assert_file "$encrypted_config"
  [[ ! -e "$TEST_REPO/Configs/$method-config.sh" ]] || fail "$method plaintext config was not removed"
  gpg --quiet --batch --yes --pinentry-mode loopback --passphrase "$TEST_PASSPHRASE" \
    --decrypt --output "$plaintext_config" "$encrypted_config"
  [[ -s "$plaintext_config" ]] || fail "$method config could not be decrypted"
done
if gpg --quiet --batch --yes --pinentry-mode loopback --passphrase "wrong-passphrase" \
  --decrypt --output "$TEST_ROOT/wrong-passphrase.out" "$TEST_REPO/Configs/webdav-config.sh.gpg" \
  >/dev/null 2>&1; then
  fail "Encrypted config decrypted with an incorrect passphrase"
fi
echo "PASS: AES-encrypted configs decrypt only with the configured passphrase"

declare -A timer_schedules=(
  [mailcow-backup]="02:00:00"
  [mailcow-ftp-upload]="03:00:00"
  [mailcow-webdav-upload]="04:00:00"
  [mailcow-nas-upload]="05:00:00"
  [mailcow-s3-upload]="06:00:00"
)
for unit in "${!timer_schedules[@]}"; do
  timer_file="$SYSTEMD_DIR/$unit.timer"
  service_file="$SYSTEMD_DIR/$unit.service"
  assert_file "$timer_file"
  assert_file "$service_file"
  assert_contains "$timer_file" "OnCalendar=*-*-* ${timer_schedules[$unit]}"
  assert_contains "$timer_file" "Unit=$unit.service"
  assert_contains "$service_file" "ExecStart=/bin/bash $TEST_REPO/"
  systemd-analyze verify "$service_file" "$timer_file" ||
    fail "systemd rejected the generated units for $unit"
  assert_contains "$MOCK_LOG_DIR/systemctl.log" "enable --now $unit.timer"
done
[[ "$(grep -c '^daemon-reload$' "$MOCK_LOG_DIR/systemctl.log")" -eq 5 ]] ||
  fail "systemd was not reloaded after creating each timer"
echo "PASS: backup and upload systemd services/timers"

printf 'test backup contents\n' > "$BACKUP_DIR/mailcow-backup_test.tar.gz"
touch "$STATUS_FILE"

bash "$TEST_REPO/Upload/FTP-Upload.sh" > "$TEST_ROOT/ftp.out"
assert_contains "$MOCK_LOG_DIR/curl.log" "ftp://ftp.example.test/backups/mailcow-backup_test.tar.gz"

ftp_plaintext="$TEST_ROOT/ftp-sftp-config.sh"
gpg --quiet --batch --yes --pinentry-mode loopback --passphrase "$TEST_PASSPHRASE" \
  --decrypt --output "$ftp_plaintext" "$TEST_REPO/Configs/ftp-config.sh.gpg"
sed -i 's/^FTP_PROTOCOL="ftp"$/FTP_PROTOCOL="sftp"/' "$ftp_plaintext"
gpg --quiet --batch --yes --pinentry-mode loopback --passphrase "$TEST_PASSPHRASE" \
  --symmetric --cipher-algo AES256 --output "$TEST_REPO/Configs/ftp-config.sh.gpg" "$ftp_plaintext"
bash "$TEST_REPO/Upload/FTP-Upload.sh" > "$TEST_ROOT/sftp.out"
assert_contains "$MOCK_LOG_DIR/curl.log" "sftp://ftp.example.test/backups/mailcow-backup_test.tar.gz"

bash "$TEST_REPO/Upload/WebDAV-Upload.sh" > "$TEST_ROOT/webdav.out"
[[ "$(<"$TEST_ROOT/webdav.out")" == *"successfully uploaded"* ]] ||
  fail "WebDAV upload did not report success for HTTP 201"
assert_contains "$MOCK_LOG_DIR/curl.log" "https://webdav.example.test/backups/mailcow-backup_test.tar.gz"
if MOCK_HTTP_CODE=500 bash "$TEST_REPO/Upload/WebDAV-Upload.sh" > "$TEST_ROOT/webdav-error.out"; then
  fail "WebDAV upload accepted HTTP 500"
fi

bash "$TEST_REPO/Upload/NAS-Upload.sh" > "$TEST_ROOT/nas.out"
assert_file "$NAS_MOUNT/mailcow/mailcow-backup_test.tar.gz"
cmp "$BACKUP_DIR/mailcow-backup_test.tar.gz" "$NAS_MOUNT/mailcow/mailcow-backup_test.tar.gz" ||
  fail "NAS upload did not copy the backup contents"

bash "$TEST_REPO/Upload/S3-Upload.sh" > "$TEST_ROOT/s3.out"
assert_contains "$MOCK_LOG_DIR/aws.log" "s3://test-bucket/mailcow/mailcow-backup_test.tar.gz"
assert_contains "$MOCK_LOG_DIR/aws.log" "--endpoint-url https://s3.example.test"
if MOCK_AWS_EXIT_CODE=1 bash "$TEST_REPO/Upload/S3-Upload.sh" > "$TEST_ROOT/s3-error.out"; then
  fail "S3 upload reported success after the AWS CLI failed"
fi
echo "PASS: FTP, SFTP, WebDAV, NAS, and S3 upload flows"

migration_repo="$TEST_ROOT/migration"
git init --quiet --bare "$TEST_ROOT/origin.git"
git init --quiet --initial-branch=V2-LEGACY "$migration_repo"
git -C "$migration_repo" config user.name "CI test"
git -C "$migration_repo" config user.email "ci@example.test"
cp "$REPO_DIR/update.sh" "$migration_repo/update.sh"
git -C "$migration_repo" add update.sh
git -C "$migration_repo" commit --quiet -m "Initial migration fixture"
git -C "$migration_repo" branch V3
git -C "$migration_repo" branch main
git -C "$migration_repo" remote add origin "$TEST_ROOT/origin.git"
git -C "$migration_repo" push --quiet --set-upstream origin V2-LEGACY V3 main

(cd "$migration_repo" && bash update.sh --v3) > "$TEST_ROOT/migration-v3.out"
[[ "$(git -C "$migration_repo" branch --show-current)" == "V3" ]] ||
  fail "Migration from V2-LEGACY to V3 did not switch branches"
(cd "$migration_repo" && bash update.sh --main) > "$TEST_ROOT/migration-main.out"
[[ "$(git -C "$migration_repo" branch --show-current)" == "main" ]] ||
  fail "Migration from V3 to main did not switch branches"
if downgrade_output=$(cd "$migration_repo" && bash update.sh --v2 2>&1); then
  fail "Migration allowed a blocked downgrade from main to V2-LEGACY"
fi
[[ "$downgrade_output" == *"Downgrade not allowed"* ]] ||
  fail "Blocked migration did not explain the downgrade restriction"
(cd "$migration_repo" && printf 'y\n' | bash update.sh --v3) > "$TEST_ROOT/migration-back-to-v3.out"
[[ "$(git -C "$migration_repo" branch --show-current)" == "V3" ]] ||
  fail "Confirmed migration from main to V3 did not complete"
echo "PASS: supported and blocked branch migrations"
