#!/usr/bin/env bash
# lib/logging.sh — one log file per deploy run, plus a rolling summary.

DEPLOY_LOG=""

start_deploy_log() {
  DEPLOY_LOG="$LOG_DIR/deploy-$(ts).log"
  {
    echo "DeployKit run — $(date -Iseconds)"
    echo "Project: $PROJECT_NAME"
    echo "----------------------------------------"
  } > "$DEPLOY_LOG"
}

log_line() {
  local line="$*"
  echo "$line" | tee -a "$DEPLOY_LOG" >/dev/null
}

finish_deploy_log() {
  local status="$1"
  {
    echo "----------------------------------------"
    echo "Result: $status"
    echo "Finished: $(date -Iseconds)"
  } >> "$DEPLOY_LOG"

  # keep a single "last deploy" pointer for `deploykit status`
  echo "$DEPLOY_LOG" > "$LOG_DIR/.last_deploy"
}
