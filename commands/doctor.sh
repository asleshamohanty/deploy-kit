#!/usr/bin/env bash
# commands/doctor.sh — one-shot diagnostic report.

cmd_doctor() {
  load_config
  validate_config

  echo "${C_BLUE}DeployKit Doctor — $PROJECT_NAME${C_RESET}"
  echo "----------------------------------------"

  printf "%-14s %s\n" "OS" "$(source /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
  printf "%-14s %s\n" "Node" "$(node -v 2>/dev/null || echo 'not found')"
  printf "%-14s %s\n" "PM2" "$(pm2_is_healthy && echo Running || echo 'Not running')"
  printf "%-14s %s\n" "Nginx" "$(nginx_is_running && echo Running || echo 'Not running')"
  printf "%-14s %s\n" "Backend" "$(backend_health_check && echo Healthy || echo Unhealthy)"
  printf "%-14s %s\n" "Frontend" "$(frontend_health_check && echo Healthy || echo Unhealthy)"

  local ssl_days; ssl_days="$(ssl_days_remaining)"
  if [[ "$ssl_days" -gt 0 ]]; then
    printf "%-14s %s\n" "SSL" "Valid (${ssl_days}d left)"
  else
    printf "%-14s %s\n" "SSL" "Missing or expired"
  fi

  read -r disk ram cpu <<< "$(system_resources | sed -E 's/[a-z]+=//g')"
  printf "%-14s %s\n" "Disk" "$disk"
  printf "%-14s %s\n" "RAM" "$ram"
  printf "%-14s %s\n" "CPU" "$cpu"

  local last_deploy
  if [[ -f "$LOG_DIR/.last_deploy" ]]; then
    last_deploy="$(cat "$LOG_DIR/.last_deploy")"
    printf "%-14s %s\n" "Last deploy" "$(basename "$last_deploy")"
  fi

  echo "----------------------------------------"
  if backend_health_check && frontend_health_check && nginx_is_running && pm2_is_healthy; then
    ok "Everything looks good."
  else
    warn "Something needs attention above."
  fi
}
