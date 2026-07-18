# tests/test_helper.bash — common setup for all bats files.
# Sourced via `load test_helper` at the top of each .bats file.

DEPLOYKIT_ROOT_FOR_TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source a lib file in isolation without triggering the die/exit paths
# that real commands rely on — tests call individual functions directly.
load_lib() {
  # shellcheck disable=SC1090
  source "$DEPLOYKIT_ROOT_FOR_TESTS/lib/$1.sh"
}

# Minimal stand-ins so lib files that call these (die, warn, info, ok)
# don't require sourcing the full utils.sh color/tty setup in every test.
# die() must actually terminate execution here — real die() calls exit 1,
# and tests that exercise failure paths rely on that via bats' `run`,
# which safely captures a subshell's exit rather than killing the suite.
die()  { echo "DIE: $*" >&2; exit 1; }
warn() { :; }
info() { :; }
ok()   { :; }
