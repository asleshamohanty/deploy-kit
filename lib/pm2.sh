#!/usr/bin/env bash

# lib/pm2.sh — controlled wrapper around the production PM2 instance.

tms_pm2() {
  sudo /usr/local/sbin/tms-pm2 "$@"
}

pm2_status() {
  tms_pm2 status | node -e '
    const apps = JSON.parse(require("fs").readFileSync(0, "utf8"));
    const name = process.argv[1];
    const app = apps.find(a => a.name === name);
    if (!app) {
      console.log("not_found");
      process.exit(0);
    }
    console.log(app.pm2_env.status);
  ' "$PM2_APP" 2>/dev/null || echo "unknown"
}

pm2_restart_or_start() {
  local status
  status="$(pm2_status)"

  case "$status" in
    online)
      tms_pm2 restart
      ;;
    not_found)
      tms_pm2 start
      ;;
    *)
      die "Refusing PM2 operation: $PM2_APP status is '$status'"
      ;;
  esac

  tms_pm2 save >/dev/null 2>&1
}

pm2_is_healthy() {
  [[ "$(pm2_status)" == "online" ]]
}
