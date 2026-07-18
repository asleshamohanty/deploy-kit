#!/usr/bin/env bats
# tests/config.bats — config loading is the first thing every command
# does, so a bad config should fail loudly here rather than mid-deploy.

load test_helper

setup() {
  load_lib config
  TEST_TMPDIR="$(mktemp -d)"
  DEPLOYKIT_ROOT="$TEST_TMPDIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

write_config() {
  echo "$1" > "$TEST_TMPDIR/deploy.config.sh"
  CONFIG_FILE="$TEST_TMPDIR/deploy.config.sh"
}

@test "load_config fails when the config file doesn't exist" {
  CONFIG_FILE="$TEST_TMPDIR/does-not-exist.sh"
  run load_config
  [ "$status" -ne 0 ]
}

@test "load_config fails when a required var (PROJECT_NAME) is missing" {
  write_config "PROJECT_DIR=$TEST_TMPDIR
PM2_APP=myapp"
  run load_config
  [ "$status" -ne 0 ]
}

@test "load_config succeeds when all required vars are present" {
  write_config "PROJECT_NAME=myapp
PROJECT_DIR=$TEST_TMPDIR
PM2_APP=myapp"
  run load_config
  [ "$status" -eq 0 ]
}

@test "load_config applies sane defaults for optional vars" {
  write_config "PROJECT_NAME=myapp
PROJECT_DIR=$TEST_TMPDIR
PM2_APP=myapp"
  load_config
  [ "$BACKEND_DIR" = "$TEST_TMPDIR/backend" ]
  [ "$FRONTEND_DIR" = "$TEST_TMPDIR/frontend" ]
  [ "$BACKEND_HEALTH_PATH" = "/health" ]
  [ "$MAX_RELEASES" -eq 10 ]
  [ "$BUILD_OUTPUT_DIR" = "dist" ]
}

@test "load_config respects explicit overrides instead of defaults" {
  write_config "PROJECT_NAME=myapp
PROJECT_DIR=$TEST_TMPDIR
PM2_APP=myapp
BUILD_OUTPUT_DIR=out
FRONTEND_LOCKFILE=pnpm-lock.yaml"
  load_config
  [ "$BUILD_OUTPUT_DIR" = "out" ]
  [ "$FRONTEND_LOCKFILE" = "pnpm-lock.yaml" ]
}

@test "validate_config fails when PROJECT_DIR doesn't exist on disk" {
  write_config "PROJECT_NAME=myapp
PROJECT_DIR=/nonexistent/path/xyz
PM2_APP=myapp"
  load_config
  run validate_config
  [ "$status" -ne 0 ]
}
