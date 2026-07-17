#!/usr/bin/env bash
# commands/rollback.sh — pick a prior release and roll back to it.

cmd_rollback() {
  load_config
  validate_config

  local target="${1:-}"

  if [[ -z "$target" ]]; then
    echo "Available releases (newest first):"
    mapfile -t releases < <(list_releases)
    if [[ ${#releases[@]} -eq 0 ]]; then
      die "No releases found in $RELEASES_DIR."
    fi
    local i=1
    for r in "${releases[@]}"; do
      echo "  $i) $r"
      ((i++))
    done
    read -r -p "Choose a release number (or 1 for most recent): " idx
    target="${releases[$((idx-1))]}"
    [[ -n "$target" ]] || die "Invalid selection."
  fi

  confirm "Roll back to '$target'? This will overwrite the current webroot." || die "Aborted."
  rollback_to "$target"
}
