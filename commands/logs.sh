#!/usr/bin/env bash
# commands/logs.sh — interactive log source picker.

cmd_logs() {
  load_config

  echo "Select a log source:"
  echo "  1) PM2"
  echo "  2) Nginx error log"
  echo "  3) Nginx access log"
  echo "  4) System journal (backend service)"
  echo "  5) Live PM2 logs (follow)"
  echo "  6) DeployKit deploy logs"
  read -r -p "> " choice

  case "$choice" in
    1) pm2 logs "$PM2_APP" --lines 100 --nostream ;;
    2) sudo tail -n 100 /var/log/nginx/error.log ;;
    3) sudo tail -n 100 /var/log/nginx/access.log ;;
    4) journalctl -u "$PM2_APP" -n 100 --no-pager 2>/dev/null || warn "No systemd unit named $PM2_APP" ;;
    5) pm2 logs "$PM2_APP" ;;
    6) ls -t "$LOG_DIR"/deploy-*.log 2>/dev/null | head -1 | xargs -r cat ;;
    *) die "Invalid choice." ;;
  esac
}
