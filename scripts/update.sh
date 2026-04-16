#!/usr/bin/env sh
# Update tasks/ from the remote repository without touching .taskfile.env.
# Usage:
#   sh scripts/update.sh
#   curl -sL https://raw.githubusercontent.com/afeldman/dev-tools-task/main/scripts/update.sh | sh
set -e

REPO_URL="https://github.com/afeldman/dev-tools-task"
BRANCH="main"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { printf "${GREEN}==> ${NC}%s\n" "$1"; }
warn() { printf "${YELLOW}!   ${NC}%s\n" "$1"; }
die()  { printf "${RED}ERR ${NC}%s\n" "$1" >&2; exit 1; }

# Must be run from a directory that already has tasks/ installed
[ -d "./tasks" ] || die "No tasks/ directory found. Run scripts/install.sh first."

printf "\n${GREEN}Dev Tools Updater${NC}\n\n"
info "Fetching latest tasks from ${REPO_URL} (branch: ${BRANCH})..."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if command -v git >/dev/null 2>&1; then
  git clone --depth 1 --quiet "$REPO_URL" "$TMP/repo"
elif command -v curl >/dev/null 2>&1; then
  curl -sL "${REPO_URL}/archive/refs/heads/${BRANCH}.tar.gz" \
    | tar xz -C "$TMP"
  mv "$TMP"/*-"$BRANCH" "$TMP/repo"
else
  die "Neither git nor curl found. Install one of them and try again."
fi

# Show remote version if available
if [ -f "$TMP/repo/VERSION" ]; then
  REMOTE_VERSION=$(cat "$TMP/repo/VERSION")
  LOCAL_VERSION=""
  [ -f "./VERSION" ] && LOCAL_VERSION=$(cat ./VERSION)
  if [ -n "$LOCAL_VERSION" ]; then
    info "Updating from v${LOCAL_VERSION} → v${REMOTE_VERSION}"
  else
    info "Remote version: v${REMOTE_VERSION}"
  fi
fi

# Replace tasks/ with the latest version
rm -rf ./tasks
cp -r "$TMP/repo/tasks" .
info "tasks/ updated."

# Update VERSION file
if [ -f "$TMP/repo/VERSION" ]; then
  cp "$TMP/repo/VERSION" ./VERSION
  info "VERSION updated to $(cat ./VERSION)."
fi

# Do NOT overwrite Taskfile.yml or .taskfile.env
warn "Taskfile.yml and .taskfile.env were NOT modified."
warn "Review the CHANGELOG for breaking changes before running tasks."

echo ""
info "Update complete. Run 'task' to list all available tasks."
