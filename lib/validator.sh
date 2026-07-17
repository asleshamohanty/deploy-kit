#!/usr/bin/env bash
# lib/validator.sh — everything here must pass before deploy.sh touches
# a running service. Fail loud, fail early, fail before anything is broken.

preflight_check() {
  local failures=0

  require_cmd git
  require_cmd node
  require_cmd npm
  require_cmd pm2
  require_cmd curl

  [[ -d "$PROJECT_DIR" ]] || { err "PROJECT_DIR missing: $PROJECT_DIR"; ((failures++)); }
  [[ -d "$BACKEND_DIR" ]] || { err "BACKEND_DIR missing: $BACKEND_DIR"; ((failures++)); }

  if [[ ! -f "$BACKEND_DIR/.env" ]]; then
    warn "$BACKEND_DIR/.env not found — backend may fail to start."
  fi

  # single-flight lock: refuse to run two deploys at once
  local lock="$LOG_DIR/.deploy.lock"
  if [[ -f "$lock" ]] && kill -0 "$(cat "$lock")" 2>/dev/null; then
    err "Another deploy is already running (pid $(cat "$lock"))."
    ((failures++))
  fi

  [[ "$failures" -eq 0 ]]
}

acquire_lock() {
  echo $$ > "$LOG_DIR/.deploy.lock"
}

release_lock() {
  rm -f "$LOG_DIR/.deploy.lock"
}
