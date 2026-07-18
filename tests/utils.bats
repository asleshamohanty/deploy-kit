#!/usr/bin/env bats
# tests/utils.bats

load test_helper

setup() {
  load_lib utils
}

@test "pct computes integer percentage" {
  result="$(pct 50 200)"
  [ "$result" = "25%" ]
}

@test "pct handles zero total without dividing by zero" {
  result="$(pct 10 0)"
  [ "$result" = "0%" ]
}

@test "pct rounds down (integer division), matching doctor's display style" {
  result="$(pct 1 3)"
  [ "$result" = "33%" ]
}

@test "ts produces a sortable YYYY-MM-DD-HHMM format" {
  result="$(ts)"
  [[ "$result" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}$ ]]
}

@test "run_step returns success and prints the label when the command succeeds" {
  run run_step "test step" true
  [ "$status" -eq 0 ]
}

@test "run_step fails the whole pipeline when the command fails (fail-fast principle)" {
  run run_step "test step" false
  [ "$status" -ne 0 ]
}

@test "require_cmd passes for a command that exists" {
  run require_cmd bash
  [ "$status" -eq 0 ]
}

@test "require_cmd fails clearly for a command that does not exist" {
  run require_cmd definitely-not-a-real-command-xyz
  [ "$status" -ne 0 ]
}
