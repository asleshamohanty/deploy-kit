#!/usr/bin/env bash
# lib/pm2.sh — thin, defensive wrapper around pm2 for one app.

pm2_status() {
  pm2 jlist 2>/dev/null | node -e '
    const apps = JSON.parse(require("fs").readFileSync(0, "utf8"));
    const name = process.argv[1];
    const app = apps.find(a => a.name === name);
    if (!app) { console.log("not_found"); process.exit(0); }
    console.log(app.pm2_env.status);
  ' "$PM2_APP" 2>/dev/null || echo "unknown"
}

pm2_restart_or_start() {
  cd "$BACKEND_DIR" || die "Cannot cd into BACKEND_DIR"
  if [[ "$(pm2_status)" == "not_found" ]]; then
    if [[ -f "$DEPLOYKIT_ROOT/templates/ecosystem.config.cjs" ]]; then
      pm2 start "$DEPLOYKIT_ROOT/templates/ecosystem.config.cjs" --only "$PM2_APP"
    else
      pm2 start npm --name "$PM2_APP" -- start
    fi
  else
    pm2 restart "$PM2_APP" --update-env
  fi
  pm2 save >/dev/null 2>&1
}

pm2_is_healthy() {
  [[ "$(pm2_status)" == "online" ]]
}
