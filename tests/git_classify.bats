#!/usr/bin/env bats
# tests/git_classify.bats — the core claim of DeployKit is "only rebuild
# what changed." This is the test suite that actually proves it.

load test_helper

setup() {
  load_lib git
  BACKEND_LOCKFILE=package-lock.json
  FRONTEND_LOCKFILE=package-lock.json
}

@test "backend-only change restarts backend, does not touch frontend" {
  CHANGED_FILES=(backend/src/routes/auth.js)
  classify_changes
  [ "$NEEDS_BACKEND_RESTART" -eq 1 ]
  [ "$NEEDS_FRONTEND_BUILD" -eq 0 ]
  [ "$NEEDS_NGINX_RELOAD" -eq 0 ]
}

@test "frontend-only change rebuilds frontend, does not restart backend" {
  CHANGED_FILES=(frontend/src/Home.jsx)
  classify_changes
  [ "$NEEDS_FRONTEND_BUILD" -eq 1 ]
  [ "$NEEDS_BACKEND_RESTART" -eq 0 ]
}

@test "backend lockfile change triggers install AND restart" {
  CHANGED_FILES=(backend/package-lock.json)
  classify_changes
  [ "$NEEDS_NPM_INSTALL_BACKEND" -eq 1 ]
  [ "$NEEDS_BACKEND_RESTART" -eq 1 ]
  [ "$NEEDS_NPM_INSTALL_FRONTEND" -eq 0 ]
}

@test "frontend lockfile change triggers install AND build" {
  CHANGED_FILES=(frontend/package-lock.json)
  classify_changes
  [ "$NEEDS_NPM_INSTALL_FRONTEND" -eq 1 ]
  [ "$NEEDS_FRONTEND_BUILD" -eq 1 ]
}

@test "nginx template change triggers reload only, not a full rebuild" {
  CHANGED_FILES=(templates/nginx.conf)
  classify_changes
  [ "$NEEDS_NGINX_RELOAD" -eq 1 ]
  [ "$NEEDS_BACKEND_RESTART" -eq 0 ]
  [ "$NEEDS_FRONTEND_BUILD" -eq 0 ]
}

@test "README-only change triggers nothing (matches spec's 'do nothing' case)" {
  CHANGED_FILES=(README.md)
  classify_changes
  [ "$NEEDS_BACKEND_RESTART" -eq 0 ]
  [ "$NEEDS_FRONTEND_BUILD" -eq 0 ]
  [ "$NEEDS_NGINX_RELOAD" -eq 0 ]
  [ "$NEEDS_NPM_INSTALL_BACKEND" -eq 0 ]
  [ "$NEEDS_NPM_INSTALL_FRONTEND" -eq 0 ]
}

@test "docs-only change triggers nothing" {
  CHANGED_FILES=(docs/architecture.md)
  classify_changes
  [ "$NEEDS_BACKEND_RESTART" -eq 0 ]
  [ "$NEEDS_FRONTEND_BUILD" -eq 0 ]
}

@test "mixed backend + frontend change sets both flags independently" {
  CHANGED_FILES=(backend/src/index.js frontend/src/App.jsx)
  classify_changes
  [ "$NEEDS_BACKEND_RESTART" -eq 1 ]
  [ "$NEEDS_FRONTEND_BUILD" -eq 1 ]
}

@test "no changed files leaves every flag at zero" {
  CHANGED_FILES=()
  classify_changes
  [ "$NEEDS_BACKEND_RESTART" -eq 0 ]
  [ "$NEEDS_FRONTEND_BUILD" -eq 0 ]
  [ "$NEEDS_NGINX_RELOAD" -eq 0 ]
  [ "$NEEDS_NPM_INSTALL_BACKEND" -eq 0 ]
  [ "$NEEDS_NPM_INSTALL_FRONTEND" -eq 0 ]
}

@test "unrecognized top-level file triggers no action (fails safe, not loud)" {
  CHANGED_FILES=(some-random-file.txt)
  classify_changes
  [ "$NEEDS_BACKEND_RESTART" -eq 0 ]
  [ "$NEEDS_FRONTEND_BUILD" -eq 0 ]
  [ "$NEEDS_NGINX_RELOAD" -eq 0 ]
}

@test "respects custom lockfile names (pnpm-lock.yaml) instead of hardcoded npm default" {
  BACKEND_LOCKFILE=pnpm-lock.yaml
  FRONTEND_LOCKFILE=pnpm-lock.yaml
  CHANGED_FILES=(backend/pnpm-lock.yaml)
  classify_changes
  [ "$NEEDS_NPM_INSTALL_BACKEND" -eq 1 ]
  [ "$NEEDS_BACKEND_RESTART" -eq 1 ]
}

@test "does not false-positive on package-lock.json when custom lockfile is configured" {
  BACKEND_LOCKFILE=pnpm-lock.yaml
  CHANGED_FILES=(backend/package-lock.json)
  classify_changes
  # falls through to the generic backend/* case: restart, but no install flag
  [ "$NEEDS_NPM_INSTALL_BACKEND" -eq 0 ]
  [ "$NEEDS_BACKEND_RESTART" -eq 1 ]
}
