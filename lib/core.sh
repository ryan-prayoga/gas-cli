# shellcheck shell=bash
# Core globals and common helpers.

CLI_NAME="gas"
CLI_VERSION="0.1.0"

PROJECT_DIR="$(pwd -P)"

NO_UI=0
ASSUME_YES=0
UI_ENABLED=0
GUM_ENABLED=0

BUILD_TYPE=""
BUILD_PORT=""
BUILD_PM2_NAME=""
BUILD_GIT_PULL=""
BUILD_INSTALL_DEPS="auto"
BUILD_INSTALL_RAN="no"
BUILD_RUN_MODE=""
BUILD_STRATEGY=""
BUILD_STRATEGY_FINAL=""
BUILD_SVELTE_STRATEGY=""
BUILD_SVELTE_STRATEGY_FINAL=""
BUILD_REUSE_ECOSYSTEM=""
BUILD_USE_ECOSYSTEM_CONFIG=""
BUILD_ECOSYSTEM_FILE=""
BUILD_ECOSYSTEM_STATE="not-used"
BUILD_ECOSYSTEM_DEFAULT_NAME=""
BUILD_ECOSYSTEM_DEFAULT_PORT=""
BUILD_ECOSYSTEM_DEFAULT_SCRIPT=""
BUILD_ECOSYSTEM_DEFAULT_ARGS=""
BUILD_ECOSYSTEM_DEFAULT_CWD=""
BUILD_STACK_ID=""
BUILD_STACK_LABEL=""
BUILD_STACK_CONFIDENCE=""
BUILD_STACK_NOTES=""

BUILD_ENV_FILE=""
BUILD_START_FILE=""
BUILD_GO_TARGET=""
BUILD_NODE_VERSION=""
BUILD_NPM_VERSION=""
BUILD_GO_VERSION=""
BUILD_VERIFY_STATUS=""
BUILD_VERIFY_MESSAGE=""
BUILD_HEALTH_STATUS="skipped"
BUILD_HEALTH_PATH=""
BUILD_SVELTE_ECOSYSTEM_MODE=""
BUILD_GIT_CHANGED_FILES=""
BUILD_GIT_PULL_SUCCESS=0
BUILD_NODE_DEPS_INSTALLED=0
BUILD_GO_DEPS_RAN=0
FORCE_NODE_INSTALL=0
FORCE_GO_TIDY=0
GO_DETECTED_PORT=""
GO_SHOULD_UPDATE_ENV=0
SVELTE_BUILD_DONE=0
SVELTE_LAST_ERROR=""

log_info() {
  printf '[%s] %s\n' "$CLI_NAME" "$*" >&2
}

log_warn() {
  printf '[%s][warn] %s\n' "$CLI_NAME" "$*" >&2
}

log_error() {
  printf '[%s][error] %s\n' "$CLI_NAME" "$*" >&2
}

die() {
  log_error "$*"
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

is_interactive_terminal() {
  [[ -t 0 && -t 1 ]]
}

init_ui_mode() {
  UI_ENABLED=0
  GUM_ENABLED=0

  if (( NO_UI == 0 )) && is_interactive_terminal; then
    UI_ENABLED=1
  fi

  if (( UI_ENABLED == 1 )) && command_exists gum; then
    GUM_ENABLED=1
  fi
}

normalize_yes_no() {
  local value
  value="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  case "$value" in
    yes|y|true|1) printf 'yes\n' ;;
    no|n|false|0) printf 'no\n' ;;
    *) return 1 ;;
  esac
}

validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || return 1
  (( port >= 1 && port <= 65535 ))
}

require_command() {
  local cmd="$1"
  local message="$2"
  command_exists "$cmd" || die "$message"
}

run_shell_step() {
  local title="$1"
  local command_text="$2"

  if (( UI_ENABLED == 1 )) && (( GUM_ENABLED == 1 )); then
    gum spin --spinner dot --title "$title" -- bash -lc "$command_text"
  else
    log_info "$title"
    bash -lc "$command_text"
  fi
}

to_shell_quoted() {
  printf '%q' "$1"
}
