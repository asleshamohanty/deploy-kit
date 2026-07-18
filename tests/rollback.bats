#!/usr/bin/env bats
# tests/rollback.bats — release retention/pruning logic, tested against
# a real temp directory rather than mocked filesystem calls.

load test_helper

setup() {
  load_lib rollback
  RELEASES_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$RELEASES_DIR"
}

# Creates a release dir with a controllable mtime so pruning order is
# deterministic (ts() only has minute resolution, too coarse for a fast
# test loop).
make_release() {
  local name="$1" mtime="$2"
  mkdir -p "$RELEASES_DIR/$name"
  touch -d "$mtime" "$RELEASES_DIR/$name"
}

@test "list_releases returns releases newest-first" {
  make_release "2026-01-01-0000" "2026-01-01 00:00"
  make_release "2026-01-02-0000" "2026-01-02 00:00"
  make_release "2026-01-03-0000" "2026-01-03 00:00"

  result="$(list_releases)"
  first_line="$(echo "$result" | head -1)"
  [ "$first_line" = "2026-01-03-0000" ]
}

@test "prune_old_releases keeps exactly MAX_RELEASES when over the limit" {
  MAX_RELEASES=2
  make_release "r1" "2026-01-01 00:00"
  make_release "r2" "2026-01-02 00:00"
  make_release "r3" "2026-01-03 00:00"
  make_release "r4" "2026-01-04 00:00"

  prune_old_releases

  remaining="$(list_releases | wc -l)"
  [ "$remaining" -eq 2 ]
}

@test "prune_old_releases removes the oldest releases first" {
  MAX_RELEASES=2
  make_release "oldest" "2026-01-01 00:00"
  make_release "middle" "2026-01-02 00:00"
  make_release "newest" "2026-01-03 00:00"

  prune_old_releases

  [ ! -d "$RELEASES_DIR/oldest" ]
  [ -d "$RELEASES_DIR/newest" ]
  [ -d "$RELEASES_DIR/middle" ]
}

@test "prune_old_releases is a no-op when under the limit" {
  MAX_RELEASES=10
  make_release "r1" "2026-01-01 00:00"
  make_release "r2" "2026-01-02 00:00"

  prune_old_releases

  [ -d "$RELEASES_DIR/r1" ]
  [ -d "$RELEASES_DIR/r2" ]
}

@test "rollback_to refuses to proceed for a release that doesn't exist" {
  run rollback_to "nonexistent-release"
  [ "$status" -ne 0 ]
}
