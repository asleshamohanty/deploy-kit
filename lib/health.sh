#!/usr/bin/env bash
# lib/health.sh — HTTP health checks with retry, so a slow-starting
# process doesn't get flagged as a failed deploy.

# http_check <url> <retries> <delay_seconds>
http_check() {
  local url="$1" retries="${2:-5}" delay="${3:-2}"
  local i
  for ((i = 1; i <= retries; i++)); do
    if curl --fail --silent --max-time 5 -o /dev/null "$url"; then
      return 0
    fi
    sleep "$delay"
  done
  return 1
}

backend_health_check() {
  http_check "http://127.0.0.1:${BACKEND_PORT}${BACKEND_HEALTH_PATH}" 6 2
}

frontend_health_check() {
  http_check "https://${DOMAIN}${FRONTEND_HEALTH_PATH}" 3 2
}

system_resources() {
  local disk_pct ram_used ram_total cpu
  disk_pct=$(df -h "$PROJECT_DIR" | awk 'NR==2{print $5}')
  ram_total=$(free -m | awk '/Mem:/{print $2}')
  ram_used=$(free -m | awk '/Mem:/{print $3}')
  cpu=$(top -bn1 | awk '/Cpu\(s\)/{print $2"%"}' 2>/dev/null || echo "n/a")
  echo "disk=$disk_pct ram=$(pct "$ram_used" "$ram_total") cpu=$cpu"
}
