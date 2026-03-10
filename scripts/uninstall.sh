#!/usr/bin/env sh
# Remove all artefacts installed by scripts/install.sh.
# Usage:
#   sh scripts/uninstall.sh           # prompts for confirmation
#   sh scripts/uninstall.sh --yes     # skip confirmation
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { printf "${GREEN}==> ${NC}%s\n" "$1"; }
warn() { printf "${YELLOW}!   ${NC}%s\n" "$1"; }
die()  { printf "${RED}ERR ${NC}%s\n" "$1" >&2; exit 1; }

SKIP_CONFIRM=false
[ "$1" = "--yes" ] && SKIP_CONFIRM=true

printf "\n${RED}Lynqtech Dev Tools Uninstaller${NC}\n\n"
warn "The following will be removed from the current directory:"
echo ""

FOUND=""
[ -d "./tasks" ]          && { echo "  - tasks/";          FOUND=1; }
[ -f "./Taskfile.yml" ]   && { echo "  - Taskfile.yml";    FOUND=1; }
[ -f "./.taskfile.env" ]  && { echo "  - .taskfile.env";   FOUND=1; }
[ -f "./VERSION" ]        && { echo "  - VERSION";         FOUND=1; }

if [ -z "$FOUND" ]; then
  info "Nothing to remove — no dev-tool-tasks artefacts found."
  exit 0
fi

echo ""

if [ "$SKIP_CONFIRM" = false ]; then
  printf "${YELLOW}?   ${NC}Continue? [y/N] "
  read -r answer </dev/tty
  case "$answer" in
    [yY]|[yY][eE][sS]) ;;
    *) info "Aborted."; exit 0 ;;
  esac
fi

# Remove artefacts
[ -d "./tasks" ]         && { rm -rf ./tasks;         info "Removed tasks/"; }
[ -f "./Taskfile.yml" ]  && { rm -f  ./Taskfile.yml;  info "Removed Taskfile.yml"; }
[ -f "./.taskfile.env" ] && { rm -f  ./.taskfile.env; info "Removed .taskfile.env"; }
[ -f "./VERSION" ]       && { rm -f  ./VERSION;       info "Removed VERSION"; }

# Clean up .gitignore entry
if [ -f ".gitignore" ] && grep -q '\.taskfile\.env' .gitignore; then
  # Remove the block added by install.sh
  TMP=$(mktemp)
  grep -v '# dev-tool-tasks local config' .gitignore \
    | grep -v '\.taskfile\.env' > "$TMP"
  mv "$TMP" .gitignore
  info "Removed .taskfile.env from .gitignore"
fi

echo ""
info "Uninstall complete."
