#!/usr/bin/env bash
# lib/nginx.sh — validate + reload nginx safely (never reload on a bad config).

nginx_test() {
  sudo nginx -t >/dev/null 2>&1
}

nginx_reload() {
  if nginx_test; then
    sudo systemctl reload nginx
    ok "Nginx reloaded"
  else
    err "Nginx config test failed — refusing to reload. Run 'sudo nginx -t' to see why."
    return 1
  fi
}

nginx_is_running() {
  systemctl is-active --quiet nginx
}
