#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

fail() {
  echo "FAIL: $*" >&2
  exit 1
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
echo "PASS: update rejects unknown arguments"
