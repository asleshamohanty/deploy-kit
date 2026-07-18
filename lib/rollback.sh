#!/usr/bin/env bash
# lib/rollback.sh — atomic-ish rollback via symlink swap over release dirs.
#
# Layout:
#   releases/2026-07-17-0900/  (a copy of WEBROOT contents at that deploy)
#   releases/2026-07-17-1830/
#   current -> releases/2026-07-17-1830   (symlink WEBROOT points at)

snapshot_release() {
  local release_dir
  release_dir="$RELEASES_DIR/$(ts)"
  mkdir -p "$release_dir"
  if [[ -d "$WEBROOT" ]]; then
    cp -a "$WEBROOT/." "$release_dir/" 2>/dev/null || true
  fi
  ln -sfn "$release_dir" "$RELEASES_DIR/current"
  prune_old_releases
  echo "$release_dir"
}

prune_old_releases() {
  local count
  count=$(find "$RELEASES_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l)
  if (( count > MAX_RELEASES )); then
    find "$RELEASES_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%T@ %p\n' \
      | sort -n | head -n $(( count - MAX_RELEASES )) | cut -d' ' -f2- \
      | xargs -r rm -rf
  fi
}

list_releases() {
  find "$RELEASES_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort -r
}

rollback_to() {
  local target="$1"
  local target_dir="$RELEASES_DIR/$target"
  [[ -d "$target_dir" ]] || die "No such release: $target"

  info "Rolling back to $target"
  rsync -a --delete "$target_dir/" "$WEBROOT/" 2>/dev/null \
    || cp -a "$target_dir/." "$WEBROOT/"
  ln -sfn "$target_dir" "$RELEASES_DIR/current"

  pm2_restart_or_start
  nginx_reload || warn "Nginx reload failed during rollback — check config manually."

  if backend_health_check && frontend_health_check; then
    ok "Rollback to $target succeeded and health checks passed."
  else
    err "Rollback completed but health checks are failing — investigate immediately."
    return 1
  fi
}
