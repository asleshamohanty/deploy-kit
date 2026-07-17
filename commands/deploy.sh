#!/usr/bin/env bash
# commands/deploy.sh — the full deploy pipeline described in the spec,
# steps 1–18, with smart change detection driving steps 6–13.

cmd_deploy() {
  local dry_run=0
  [[ "${1:-}" == "--dry-run" ]] && dry_run=1

  load_config
  validate_config

  info "Preflight checks…"
  preflight_check || die "Preflight failed. Fix the issues above and retry."
  ok "Preflight passed"

  if [[ "$dry_run" -eq 1 ]]; then
    echo
    echo "${C_DIM}DRY RUN — showing the pipeline, executing nothing.${C_RESET}"
    cat <<'EOF'
  1. Validate configuration            [done above]
  2. Check SSH / lock                  [would check]
  3. Verify git state                  [would check for local changes]
  4. Pull latest code                  [would git pull --ff-only]
  5. Detect changed files              [would diff old..new HEAD]
  6-7. Install deps if lockfiles changed
  8-9. Build + deploy frontend if changed
  10. Restart backend if changed
  11-13. Validate & reload PM2 / Nginx as needed
  14-16. Health + SSL checks
  17-18. Save log, print summary
EOF
    return 0
  fi

  acquire_lock
  trap release_lock EXIT
  start_deploy_log

  git_check_clean
  git_pull_and_diff
  classify_changes

  log_line "Changed files: ${#CHANGED_FILES[@]}"
  for f in "${CHANGED_FILES[@]}"; do log_line "  - $f"; done

  if [[ "$NEEDS_NPM_INSTALL_BACKEND" -eq 1 ]]; then
    run_step "Install backend deps" bash -c "cd '$BACKEND_DIR' && $BACKEND_INSTALL_CMD"
  fi
  if [[ "$NEEDS_NPM_INSTALL_FRONTEND" -eq 1 ]]; then
    run_step "Install frontend deps" bash -c "cd '$FRONTEND_DIR' && $FRONTEND_INSTALL_CMD"
  fi

  if [[ "$NEEDS_FRONTEND_BUILD" -eq 1 ]]; then
    run_step "Build frontend" bash -c "cd '$FRONTEND_DIR' && $FRONTEND_BUILD_CMD"
    run_step "Snapshot + deploy frontend to webroot" bash -c "
      mkdir -p '$WEBROOT'
      rsync -a --delete '$FRONTEND_DIR/$BUILD_OUTPUT_DIR/' '$WEBROOT/' 2>/dev/null \
        || cp -a '$FRONTEND_DIR/$BUILD_OUTPUT_DIR/.' '$WEBROOT/'
    "
    snapshot_release >/dev/null
  else
    info "Frontend unchanged — skipping build/deploy."
  fi

  if [[ "$NEEDS_BACKEND_RESTART" -eq 1 ]]; then
    run_step "Restart backend (PM2)" pm2_restart_or_start
  else
    info "Backend unchanged — skipping restart."
  fi

  run_step "Validate PM2" pm2_is_healthy

  if [[ "$NEEDS_NGINX_RELOAD" -eq 1 ]]; then
    run_step "Reload Nginx" nginx_reload
  else
    run_step "Validate Nginx config" nginx_test
  fi

  run_step "Backend health check" backend_health_check
  run_step "Frontend health check" frontend_health_check

  if ssl_is_valid; then
    ok "SSL certificate valid ($(ssl_days_remaining) days remaining)"
  else
    warn "SSL certificate missing or expired for $DOMAIN"
  fi

  finish_deploy_log "SUCCESS"

  echo
  echo "${C_GREEN}Deployment summary${C_RESET}"
  echo "  Project:        $PROJECT_NAME"
  echo "  Backend:        $([[ $NEEDS_BACKEND_RESTART -eq 1 ]] && echo restarted || echo unchanged)"
  echo "  Frontend:       $([[ $NEEDS_FRONTEND_BUILD -eq 1 ]] && echo rebuilt || echo unchanged)"
  echo "  Nginx:          $([[ $NEEDS_NGINX_RELOAD -eq 1 ]] && echo reloaded || echo unchanged)"
  echo "  SSL expires in: $(ssl_days_remaining) days"
  echo "  Log:            $DEPLOY_LOG"
}
