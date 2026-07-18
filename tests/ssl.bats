#!/usr/bin/env bats
# tests/ssl.bats — generates real self-signed certs with controlled
# expiry dates rather than mocking openssl output, so this tests the
# actual date-math logic against real cert parsing.

load test_helper

setup() {
  load_lib ssl
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

make_cert_expiring_in_days() {
  local days="$1"
  openssl req -x509 -newkey rsa:2048 -keyout "$TEST_TMPDIR/key.pem" \
    -out "$TEST_TMPDIR/fullchain.pem" -days "$days" -nodes \
    -subj "/CN=test.example.com" >/dev/null 2>&1
}

@test "ssl_days_remaining reports ~30 days for a cert issued with -days 30" {
  make_cert_expiring_in_days 30
  ssl_cert_path() { echo "$TEST_TMPDIR/fullchain.pem"; }
  result="$(ssl_days_remaining)"
  # allow a 1-day slop for test execution time / rounding
  [ "$result" -ge 29 ] && [ "$result" -le 30 ]
}

@test "ssl_is_valid returns true for a cert that hasn't expired" {
  make_cert_expiring_in_days 90
  ssl_cert_path() { echo "$TEST_TMPDIR/fullchain.pem"; }
  run ssl_is_valid
  [ "$status" -eq 0 ]
}

@test "ssl_days_remaining returns -1 when no cert file exists" {
  ssl_cert_path() { echo "$TEST_TMPDIR/does-not-exist.pem"; }
  result="$(ssl_days_remaining)"
  [ "$result" -eq -1 ]
}

@test "ssl_is_valid returns false (nonzero) when no cert exists" {
  ssl_cert_path() { echo "$TEST_TMPDIR/does-not-exist.pem"; }
  run ssl_is_valid
  [ "$status" -ne 0 ]
}
