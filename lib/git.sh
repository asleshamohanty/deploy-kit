#!/usr/bin/env bash
# lib/git.sh — repo state, pulling, and change classification.
# This is the heart of "smart change detection": we diff the two commits
# that bracket the pull and classify every changed path, so deploy.sh
# only rebuilds/restarts what actually needs it.

git_check_clean() {
  cd "$PROJECT_DIR" || die "Cannot cd into PROJECT_DIR"
  if [[ -n "$(git status --porcelain)" ]]; then
    warn "Working tree has local changes:"
    git status --short
    confirm "Continue anyway (local changes will remain, untouched by pull)?" || die "Aborted by user."
  fi
}

# git_pull_and_diff — pulls, then prints the set of changed files between
# the previous HEAD and the new one. Sets CHANGED_FILES (array, global).
git_pull_and_diff() {
  cd "$PROJECT_DIR" || die "Cannot cd into PROJECT_DIR"
  local before after
  before="$(git rev-parse HEAD)"
  git fetch --quiet origin
  git pull --quiet --ff-only origin "$(git rev-parse --abbrev-ref HEAD)" \
    || die "git pull failed — is the branch fast-forwardable?"
  after="$(git rev-parse HEAD)"

  if [[ "$before" == "$after" ]]; then
    CHANGED_FILES=()
    info "No new commits (already at $after)."
    return 0
  fi

  mapfile -t CHANGED_FILES < <(git diff --name-only "$before" "$after")
  info "Pulled $before..$after — ${#CHANGED_FILES[@]} file(s) changed."
}

# classify_changes — sets boolean-ish flags based on CHANGED_FILES.
# Called after git_pull_and_diff. These globals are read by
# commands/deploy.sh, which shellcheck can't see across sourced files.
# shellcheck disable=SC2034
classify_changes() {
  NEEDS_BACKEND_RESTART=0
  NEEDS_FRONTEND_BUILD=0
  NEEDS_NPM_INSTALL_BACKEND=0
  NEEDS_NPM_INSTALL_FRONTEND=0
  NEEDS_NGINX_RELOAD=0

  local f
  for f in "${CHANGED_FILES[@]}"; do
    case "$f" in
      "backend/${BACKEND_LOCKFILE}") NEEDS_NPM_INSTALL_BACKEND=1; NEEDS_BACKEND_RESTART=1 ;;
      "frontend/${FRONTEND_LOCKFILE}") NEEDS_NPM_INSTALL_FRONTEND=1; NEEDS_FRONTEND_BUILD=1 ;;
      backend/*) NEEDS_BACKEND_RESTART=1 ;;
      frontend/*) NEEDS_FRONTEND_BUILD=1 ;;
      templates/nginx.conf|*.nginx.conf) NEEDS_NGINX_RELOAD=1 ;;
      README*|docs/*|*.md) : ;; # explicitly a no-op, matches spec
      *) : ;; # unrecognized paths: no action, but still logged
    esac
  done
}
