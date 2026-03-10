#!/usr/bin/env sh
# Smoke test for scripts/install.sh
# Creates a local bare-git repo as a stand-in for GitHub so the test runs
# fully offline, then verifies that install.sh produces all expected artefacts.
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { printf "${GREEN}PASS${NC} %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "${RED}FAIL${NC} %s\n" "$1"; FAIL=$((FAIL + 1)); }

# ── Setup: local git repo as fake remote ─────────────────────────────────────
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

FAKE_REMOTE="$TMP/remote.git"
FAKE_SOURCE="$TMP/source"
TARGET="$TMP/target"

mkdir -p "$FAKE_SOURCE" "$TARGET"

# Build a minimal git repo with the same structure as the real repo
cp -r "$REPO_ROOT/tasks"       "$FAKE_SOURCE/tasks"
cp    "$REPO_ROOT/Taskfile.yml" "$FAKE_SOURCE/Taskfile.yml"

git -C "$FAKE_SOURCE" init -q
git -C "$FAKE_SOURCE" config user.email "test@test.local"
git -C "$FAKE_SOURCE" config user.name  "test"
git -C "$FAKE_SOURCE" add -A
git -C "$FAKE_SOURCE" commit -q -m "init"

git clone --quiet --bare "$FAKE_SOURCE" "$FAKE_REMOTE"

# Patch install.sh: replace REPO_URL with the local bare repo path
PATCHED="$TMP/install.sh"
sed "s|REPO_URL=.*|REPO_URL=\"file://$FAKE_REMOTE\"|" \
    "$REPO_ROOT/scripts/install.sh" > "$PATCHED"
chmod +x "$PATCHED"

# ── Helper: run the patched installer ────────────────────────────────────────
run_installer() {
  (
    cd "$TARGET"
    NAMESPACE="test-app" \
    AWS_REGION="eu-west-1" \
    AWS_PROFILE_DEV="test-dev" \
    AWS_PROFILE_PLAY="test-play" \
    KUBE_CONTEXT="test-cluster" \
    OUTPUT_DIR=".diagnostics" \
    sh "$PATCHED" >/dev/null 2>&1
  )
}

run_installer

# ── Assertions ────────────────────────────────────────────────────────────────

# 1. tasks/ directory was created
if [ -d "$TARGET/tasks" ]; then
  ok "tasks/ directory exists"
else
  fail "tasks/ directory missing"
fi

# 2. Expected task modules are present
for module in aws kube helm terraform git security diagnostics; do
  if [ -f "$TARGET/tasks/$module/Taskfile.yml" ]; then
    ok "tasks/$module/Taskfile.yml present"
  else
    fail "tasks/$module/Taskfile.yml missing"
  fi
done

# 3. Taskfile.yml was created
if [ -f "$TARGET/Taskfile.yml" ]; then
  ok "Taskfile.yml created"
else
  fail "Taskfile.yml missing"
fi

# 4. .taskfile.env was written
if [ -f "$TARGET/.taskfile.env" ]; then
  ok ".taskfile.env created"
else
  fail ".taskfile.env missing"
fi

# 5. .taskfile.env contains expected values
check_env() {
  local key="$1" expected="$2"
  actual=$(grep "^${key}=" "$TARGET/.taskfile.env" 2>/dev/null | cut -d= -f2-)
  if [ "$actual" = "$expected" ]; then
    ok ".taskfile.env: $key=$expected"
  else
    fail ".taskfile.env: $key expected '$expected', got '$actual'"
  fi
}
check_env "NAMESPACE"        "test-app"
check_env "AWS_REGION"       "eu-west-1"
check_env "AWS_PROFILE_DEV"  "test-dev"
check_env "AWS_PROFILE_PLAY" "test-play"
check_env "KUBE_CONTEXT"     "test-cluster"
check_env "OUTPUT_DIR"       ".diagnostics"

# 6. .gitignore contains .taskfile.env
if grep -q '\.taskfile\.env' "$TARGET/.gitignore" 2>/dev/null; then
  ok ".gitignore contains .taskfile.env"
else
  fail ".gitignore missing .taskfile.env entry"
fi

# 7. Taskfile.yml references dotenv
if grep -q 'dotenv' "$TARGET/Taskfile.yml" 2>/dev/null; then
  ok "Taskfile.yml contains dotenv directive"
else
  fail "Taskfile.yml missing dotenv directive"
fi

# 8. Idempotency: second run must not fail or break anything
run_installer \
  && ok "install.sh is idempotent (second run succeeded)" \
  || fail "install.sh failed on second run"

# values still intact after second run
check_env "NAMESPACE" "test-app"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
printf "Results: ${GREEN}%d passed${NC}, ${RED}%d failed${NC}\n" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
