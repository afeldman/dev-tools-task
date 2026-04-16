#!/usr/bin/env sh
# Usage:
#   Interactive:    sh install.sh
#   Via curl:       curl -sL https://raw.githubusercontent.com/afeldman/dev-tools-task/main/scripts/install.sh | sh
#   With env vars:  NAMESPACE=myapp AWS_PROFILE_DEV=my-profile sh install.sh
set -e

REPO_URL="https://github.com/afeldman/dev-tools-task"
BRANCH="main"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { printf "${GREEN}==> ${NC}%s\n" "$1"; }
warn()  { printf "${YELLOW}!   ${NC}%s\n" "$1"; }
ask()   { printf "${YELLOW}?   ${NC}%s: " "$1"; }
die()   { printf "${RED}ERR ${NC}%s\n" "$1" >&2; exit 1; }

# ── Helpers ───────────────────────────────────────────────────────────────────

# List AWS profile names from ~/.aws/config
list_aws_profiles() {
  local cfg="$HOME/.aws/config"
  [ -f "$cfg" ] || return
  grep -E '^\[(profile |default)' "$cfg" \
    | sed 's/^\[profile //;s/^\[//;s/\].*//' \
    | sort
}

# List current Kubernetes context names
list_kube_contexts() {
  local cfg="${KUBECONFIG:-$HOME/.kube/config}"
  [ -f "$cfg" ] || return
  grep -E '^\s*- context:' "$cfg" -A1 \
    | grep 'name:' \
    | awk '{print $2}' \
    | sort
}

# Show a numbered menu and return the chosen value (stdin-safe)
choose_from_list() {
  local prompt="$1"; shift
  local items="$*"
  local i=1
  for item in $items; do
    printf "  %d) %s\n" "$i" "$item"
    i=$((i + 1))
  done
  ask "$prompt (number or custom value)"
  read -r choice </dev/tty
  # if numeric, resolve to item; otherwise use as-is
  if echo "$choice" | grep -qE '^[0-9]+$'; then
    echo "$items" | tr ' ' '\n' | sed -n "${choice}p"
  else
    echo "$choice"
  fi
}

# Read a value interactively with an optional default
read_value() {
  local prompt="$1"
  local default="$2"
  if [ -n "$default" ]; then
    ask "$prompt [${default}]"
  else
    ask "$prompt"
  fi
  read -r val </dev/tty
  echo "${val:-$default}"
}

# ── Detect interactive mode ───────────────────────────────────────────────────
# When piped through curl, /dev/tty is still the terminal even though stdin is the pipe.
INTERACTIVE=true
[ -t 0 ] || INTERACTIVE=true   # /dev/tty is always available on macOS/Linux

# ── Collect configuration ─────────────────────────────────────────────────────
printf "\n${GREEN}Dev Tools Installer${NC}\n\n"

# Project namespace
if [ -z "$NAMESPACE" ]; then
  NAMESPACE=$(read_value "Project namespace / name (e.g. my-app)" "$(basename "$(pwd)")")
fi

# AWS region
if [ -z "$AWS_REGION" ]; then
  AWS_REGION=$(read_value "AWS region" "eu-central-1")
fi

# AWS profiles
AWS_PROFILES=$(list_aws_profiles)
if [ -z "$AWS_PROFILE_DEV" ]; then
  if [ -n "$AWS_PROFILES" ]; then
    echo ""
    info "Available AWS profiles:"
    AWS_PROFILE_DEV=$(choose_from_list "Dev AWS profile" $AWS_PROFILES)
  else
    warn "No AWS profiles found in ~/.aws/config"
    AWS_PROFILE_DEV=$(read_value "Dev AWS profile name" "default")
  fi
fi

if [ -z "$AWS_PROFILE_PLAY" ]; then
  if [ -n "$AWS_PROFILES" ]; then
    echo ""
    info "Available AWS profiles:"
    AWS_PROFILE_PLAY=$(choose_from_list "Playground AWS profile (leave empty to skip)" $AWS_PROFILES)
  else
    AWS_PROFILE_PLAY=$(read_value "Playground AWS profile name (leave empty to skip)" "")
  fi
fi

# Kubernetes context
KUBE_CONTEXTS=$(list_kube_contexts)
if [ -z "$KUBE_CONTEXT" ]; then
  if [ -n "$KUBE_CONTEXTS" ]; then
    echo ""
    info "Available Kubernetes contexts (${KUBECONFIG:-~/.kube/config}):"
    KUBE_CONTEXT=$(choose_from_list "Default Kubernetes context" $KUBE_CONTEXTS)
  else
    warn "No Kubernetes contexts found — skipping (set KUBE_CONTEXT in .taskfile.env later)"
    KUBE_CONTEXT=""
  fi
fi

# Diagnostics output directory
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR=$(read_value "Diagnostics output directory" ".diagnostics")
fi

# ── Download repository ───────────────────────────────────────────────────────
echo ""
info "Downloading tasks from ${REPO_URL}..."

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

# ── Copy tasks/ folder ────────────────────────────────────────────────────────
if [ -d "./tasks" ]; then
  warn "tasks/ directory already exists — overwriting."
fi
cp -r "$TMP/repo/tasks" .
info "tasks/ installed."

# ── Write .taskfile.env ───────────────────────────────────────────────────────
cat > .taskfile.env << EOF
NAMESPACE=${NAMESPACE}
AWS_REGION=${AWS_REGION}
AWS_PROFILE_DEV=${AWS_PROFILE_DEV}
AWS_PROFILE_PLAY=${AWS_PROFILE_PLAY}
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
KUBE_CONTEXT=${KUBE_CONTEXT}
OUTPUT_DIR=${OUTPUT_DIR}
EOF
info ".taskfile.env written."

# ── Add .taskfile.env to .gitignore ──────────────────────────────────────────
if [ -f .gitignore ]; then
  grep -q '\.taskfile\.env' .gitignore \
    || printf '\n# dev-tool-tasks local config\n.taskfile.env\n' >> .gitignore
else
  printf '# dev-tool-tasks local config\n.taskfile.env\n' > .gitignore
fi

# ── Install root Taskfile.yml ────────────────────────────────────────────────
if [ -f Taskfile.yml ]; then
  warn "Taskfile.yml already exists — skipping."
  warn "Make sure it includes the following dotenv and includes block:"
  cat "$TMP/repo/Taskfile.yml"
else
  cp "$TMP/repo/Taskfile.yml" Taskfile.yml
  info "Taskfile.yml installed."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
info "Done! Summary:"
printf "  NAMESPACE       = %s\n" "$NAMESPACE"
printf "  AWS_REGION      = %s\n" "$AWS_REGION"
printf "  AWS_PROFILE_DEV = %s\n" "$AWS_PROFILE_DEV"
[ -n "$AWS_PROFILE_PLAY" ] && printf "  AWS_PROFILE_PLAY = %s\n" "$AWS_PROFILE_PLAY"
[ -n "$AZURE_SUBSCRIPTION_ID" ] && printf "  AZURE_SUBSCRIPTION_ID = %s\n" "$AZURE_SUBSCRIPTION_ID"
[ -n "$KUBE_CONTEXT" ]   && printf "  KUBE_CONTEXT     = %s\n" "$KUBE_CONTEXT"
printf "  OUTPUT_DIR       = %s\n" "$OUTPUT_DIR"
echo ""
info "Run 'task' to list all available tasks."
info "Edit .taskfile.env to change project-specific settings."
