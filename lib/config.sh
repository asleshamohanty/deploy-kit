#!/usr/bin/env bash
# lib/config.sh — loads and validates deploy.config.sh
# Every command sources this before doing anything else.

DEPLOYKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${DEPLOYKIT_CONFIG:-$PWD/deploy.config.sh}"

load_config() {
  [[ -f "$CONFIG_FILE" ]] || die "No config found at $CONFIG_FILE. Copy templates/deploy.config.example.sh and edit it."
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"

  local required=(PROJECT_NAME PROJECT_DIR PM2_APP)
  local missing=()
  for var in "${required[@]}"; do
    [[ -z "${!var:-}" ]] && missing+=("$var")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required config values: ${missing[*]}"
  fi

  # sane defaults so the rest of the codebase never has to guess
  BACKEND_DIR="${BACKEND_DIR:-$PROJECT_DIR/backend}"
  FRONTEND_DIR="${FRONTEND_DIR:-$PROJECT_DIR/frontend}"
  WEBROOT="${WEBROOT:-/var/www/$PROJECT_NAME}"
  BACKEND_PORT="${BACKEND_PORT:-4000}"
  BACKEND_HEALTH_PATH="${BACKEND_HEALTH_PATH:-/health}"
  FRONTEND_HEALTH_PATH="${FRONTEND_HEALTH_PATH:-/}"
  NGINX_SITE="${NGINX_SITE:-/etc/nginx/sites-available/$PROJECT_NAME}"
  RELEASES_DIR="${RELEASES_DIR:-$DEPLOYKIT_ROOT/releases}"
  LOG_DIR="${LOG_DIR:-$DEPLOYKIT_ROOT/logs}"
  MAX_RELEASES="${MAX_RELEASES:-10}"

  # --- stack-agnostic hooks (see README "Adapting DeployKit" section) ---
  # Where the frontend build lands: dist for Vite/CRA/Vue, build for
  # some CRA setups, out for Next.js static export, public for SvelteKit.
  BUILD_OUTPUT_DIR="${BUILD_OUTPUT_DIR:-dist}"
  # Command run inside FRONTEND_DIR to produce BUILD_OUTPUT_DIR.
  FRONTEND_BUILD_CMD="${FRONTEND_BUILD_CMD:-npm run build}"
  # Command run inside BACKEND_DIR to install deps (npm ci / pnpm install / yarn install).
  BACKEND_INSTALL_CMD="${BACKEND_INSTALL_CMD:-npm ci}"
  FRONTEND_INSTALL_CMD="${FRONTEND_INSTALL_CMD:-npm ci}"
  # Lockfile names used for change detection — swap for pnpm-lock.yaml / yarn.lock.
  BACKEND_LOCKFILE="${BACKEND_LOCKFILE:-package-lock.json}"
  FRONTEND_LOCKFILE="${FRONTEND_LOCKFILE:-package-lock.json}"

  mkdir -p "$LOG_DIR" "$RELEASES_DIR"
}

validate_config() {
  [[ -d "$PROJECT_DIR" ]] || die "PROJECT_DIR does not exist: $PROJECT_DIR"
  [[ -d "$PROJECT_DIR/.git" ]] || warn "PROJECT_DIR is not a git repo — change detection will be skipped."
}
