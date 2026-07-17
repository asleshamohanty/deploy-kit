#!/usr/bin/env bash
# commands/status.sh — quick snapshot, cheaper than full `doctor`.

cmd_status() {
  load_config
  validate_config

  cd "$PROJECT_DIR" || die "Cannot cd into PROJECT_DIR"
  echo "Project:   $PROJECT_NAME"
  echo "Branch:    $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'n/a')"
  echo "Commit:    $(git rev-parse --short HEAD 2>/dev/null || echo 'n/a')"
  echo "PM2:       $(pm2_status)"
  echo "Nginx:     $(nginx_is_running && echo running || echo stopped)"
  echo "Backend:   $(backend_health_check && echo healthy || echo down)"
  echo "Frontend:  $(frontend_health_check && echo healthy || echo down)"
  echo "Current release: $(readlink -f "$RELEASES_DIR/current" 2>/dev/null | xargs -r basename)"
}
