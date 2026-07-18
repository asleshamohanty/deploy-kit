#!/usr/bin/env bash
# lib/utils.sh — shared helpers used by every DeployKit command.
# Sourced, never executed directly.

set -o pipefail

# ---- colors -----------------------------------------------------------
# Consumed by commands/*.sh — shellcheck can't trace usage across sourced
# files, so these read as "unused" here even though they aren't.
# shellcheck disable=SC2034
if [[ -t 1 ]]; then
  C_RED=$'\033[0;31m'; C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[0;33m'
  C_BLUE=$'\033[0;34m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_DIM=""; C_RESET=""
fi

info()  { echo "${C_BLUE}➜${C_RESET} $*"; }
ok()    { echo "${C_GREEN}✔${C_RESET} $*"; }
warn()  { echo "${C_YELLOW}⚠${C_RESET} $*"; }
err()   { echo "${C_RED}✘${C_RESET} $*" >&2; }
die()   { err "$*"; exit 1; }

# require_cmd <name> — fail fast with a clear message instead of a raw
# "command not found" three steps into a deploy.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command '$1' not found on PATH."
}

# confirm <prompt> — used before destructive actions (rollback, install).
confirm() {
  local prompt="${1:-Are you sure?}"
  read -r -p "${prompt} [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# timestamp for logs / release directory names: 2026-07-17-1830
ts() { date +"%Y-%m-%d-%H%M"; }

# human_bytes <kb> — quick %-used style formatting for doctor/status
pct() {
  local used=$1 total=$2
  [[ "$total" -eq 0 ]] && { echo "0%"; return; }
  echo "$(( used * 100 / total ))%"
}

# run_step <label> <cmd...> — execute a pipeline step with consistent
# logging and a single point of failure handling.
run_step() {
  local label="$1"; shift
  info "$label"
  if "$@"; then
    ok "$label"
  else
    die "$label failed"
  fi
}
