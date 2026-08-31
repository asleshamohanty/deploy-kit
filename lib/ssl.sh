#!/usr/bin/env bash
# lib/ssl.sh — certificate presence + expiry, via the cert on disk (no
# network calls needed since certbot already manages renewal).

ssl_cert_path() {
  echo "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
}

ssl_days_remaining() {
  local cert; cert="$(ssl_cert_path)"
  sudo test -f "$cert" || { echo "-1"; return; }

  local expiry_epoch now_epoch
  expiry_epoch=$(sudo openssl x509 -enddate -noout -in "$cert" | cut -d= -f2) || { echo "-1"; return; }
  expiry_epoch=$(date -d "$expiry_epoch" +%s) || { echo "-1"; return; }

  now_epoch=$(date +%s)
  echo $(( (expiry_epoch - now_epoch) / 86400 ))
}
ssl_is_valid() {
  local days; days="$(ssl_days_remaining)"
  [[ "$days" -gt 0 ]]
}
