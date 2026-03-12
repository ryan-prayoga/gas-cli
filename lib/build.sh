# shellcheck shell=bash
# Build flow and strategy execution.

maybe_git_pull() {
  if [[ -z "$BUILD_GIT_PULL" ]]; then
    if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
      BUILD_GIT_PULL="$(ui_select 'Mau jalankan git pull dulu?' 'no' yes no)"
    else
      BUILD_GIT_PULL="no"
    fi
  fi
}

extract_git_changed_files() {
  local before_head="$1"
  local after_head="$2"
  local changed=""

  if [[ -n "$before_head" && -n "$after_head" && "$before_head" != "$after_head" ]]; then
    changed="$(git diff --name-only "$before_head" "$after_head" 2>/dev/null || true)"
  fi

  if [[ -z "$changed" ]]; then
    changed="$(git diff --name-only 'HEAD@{1}' HEAD 2>/dev/null || true)"
  fi

  printf '%s\n' "$changed"
}

execute_git_pull_if_needed() {
  BUILD_GIT_PULL_SUCCESS=0
  BUILD_GIT_CHANGED_FILES=""

  if [[ "$BUILD_GIT_PULL" != "yes" ]]; then
    return
  fi

  require_command git "git tidak ditemukan. Install git dulu."

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_warn "git pull dilewati. Folder ini bukan working tree git."
    return
  fi

  local before_head=""
  local after_head=""
  before_head="$(git rev-parse HEAD 2>/dev/null || true)"

  log_info "Menjalankan git pull..."
  if ! git pull; then
    log_warn "git pull gagal. Mungkin folder ini bukan root repo git, atau root repo ada di parent."
    return
  fi

  BUILD_GIT_PULL_SUCCESS=1
  after_head="$(git rev-parse HEAD 2>/dev/null || true)"
  BUILD_GIT_CHANGED_FILES="$(extract_git_changed_files "$before_head" "$after_head")"

  if [[ -n "$BUILD_GIT_CHANGED_FILES" ]]; then
    log_info "File berubah setelah git pull terdeteksi."
  else
    log_info "Tidak ada perubahan file setelah git pull."
  fi
}


resolve_go_port_and_env() {
  local detected=""
  detected="$(detect_env_port)"
  local detected_port="${detected%%;*}"
  local env_file="${detected#*;}"
  BUILD_ENV_FILE="$env_file"
  GO_DETECTED_PORT="$detected_port"
  GO_SHOULD_UPDATE_ENV=0

  local default_port="3000"
  if [[ -n "${BUILD_ECOSYSTEM_DEFAULT_PORT:-}" ]] && validate_port "$BUILD_ECOSYSTEM_DEFAULT_PORT"; then
    default_port="$BUILD_ECOSYSTEM_DEFAULT_PORT"
  elif [[ -n "$detected_port" ]] && validate_port "$detected_port"; then
    default_port="$detected_port"
  fi

  resolve_port_input "Port" "$default_port"

  if [[ "$BUILD_PORT" != "$GO_DETECTED_PORT" ]]; then
    GO_SHOULD_UPDATE_ENV=1
  fi
}

collect_go_targets() {
  local -a targets=()

  if [[ -f "$PROJECT_DIR/main.go" ]]; then
    targets+=("./")
  fi

  local -a files=()
  shopt -s nullglob
  files=("$PROJECT_DIR"/cmd/*/main.go)
  shopt -u nullglob

  if (( ${#files[@]} > 0 )); then
    local file=""
    for file in "${files[@]}"; do
      local rel_dir=""
      rel_dir="$(dirname "${file#"$PROJECT_DIR/"}")"
      targets+=("./$rel_dir")
    done
  fi

  if (( ${#targets[@]} > 0 )); then
    local item=""
    for item in "${targets[@]}"; do
      printf '%s\n' "$item"
    done
  fi
}

resolve_go_target() {
  local -a targets=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && targets+=("$line")
  done < <(collect_go_targets)

  if (( ${#targets[@]} == 0 )); then
    die "Target Go tidak ditemukan. Perlu main.go atau cmd/*/main.go."
  fi

  if (( ${#targets[@]} == 1 )); then
    BUILD_GO_TARGET="${targets[0]}"
    return
  fi

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    BUILD_GO_TARGET="$(ui_select 'Pilih target Go untuk dibuild' "${targets[0]}" "${targets[@]}")"
  else
    BUILD_GO_TARGET="${targets[0]}"
    log_warn "Multiple target Go terdeteksi. Dipilih otomatis: $BUILD_GO_TARGET"
  fi
}

sanitize_binary_name() {
  local name="$1"
  name="${name// /-}"
  name="${name//\//-}"
  printf '%s\n' "$name"
}

has_changed_file() {
  local file_name="$1"
  [[ -n "$BUILD_GIT_CHANGED_FILES" ]] || return 1
  printf '%s\n' "$BUILD_GIT_CHANGED_FILES" | grep -Eq "(^|/)${file_name}$"
}

needs_node_install() {
  [[ -f "$PROJECT_DIR/package.json" ]] || return 1

  case "$BUILD_INSTALL_DEPS" in
    yes) return 0 ;;
    no) return 1 ;;
    auto)
      if (( FORCE_NODE_INSTALL == 1 )); then
        return 0
      fi

      if [[ ! -d "$PROJECT_DIR/node_modules" ]]; then
        return 0
      fi

      if (( BUILD_GIT_PULL_SUCCESS == 1 )) && { has_changed_file "package.json" || has_changed_file "package-lock.json" || has_changed_file "npm-shrinkwrap.json" || has_changed_file "yarn.lock" || has_changed_file "pnpm-lock.yaml"; }; then
        return 0
      fi
      return 1
      ;;
    *)
      die "Nilai --install-deps harus auto|yes|no"
      ;;
  esac
}

needs_go_mod_tidy() {
  [[ -f "$PROJECT_DIR/go.mod" ]] || return 1

  case "$BUILD_INSTALL_DEPS" in
    yes) return 0 ;;
    no) return 1 ;;
    auto)
      if (( FORCE_GO_TIDY == 1 )); then
        return 0
      fi

      if (( BUILD_GIT_PULL_SUCCESS == 1 )) && { has_changed_file "go.mod" || has_changed_file "go.sum"; }; then
        return 0
      fi
      return 1
      ;;
    *)
      die "Nilai --install-deps harus auto|yes|no"
      ;;
  esac
}

run_dependency_install() {
  local target="$1"

  case "$target" in
    node)
      if (( BUILD_NODE_DEPS_INSTALLED == 1 )); then
        return 0
      fi

      local manager=""
      manager="$(detect_package_manager)"

      local cmd=""
      case "$manager" in
        pnpm)
          require_command pnpm "pnpm-lock.yaml terdeteksi tapi pnpm tidak ditemukan. Install pnpm atau ubah lockfile."
          cmd="pnpm install"
          ;;
        yarn)
          require_command yarn "yarn.lock terdeteksi tapi yarn tidak ditemukan. Install yarn atau ubah lockfile."
          cmd="yarn install"
          ;;
        npm)
          require_command npm "npm tidak ditemukan. Install npm dulu."
          cmd="npm install"
          ;;
        *)
          die "Package manager tidak dikenali: $manager"
          ;;
      esac

      local q_dir
      q_dir="$(to_shell_quoted "$PROJECT_DIR")"
      run_shell_step "Install dependency Node (${manager})" "cd $q_dir && $cmd" || return 1

      BUILD_NODE_DEPS_INSTALLED=1
      BUILD_INSTALL_RAN="yes"
      return 0
      ;;
    go)
      if (( BUILD_GO_DEPS_RAN == 1 )); then
        return 0
      fi

      require_command go "Go tidak ditemukan. Install Go dulu."
      local q_dir
      q_dir="$(to_shell_quoted "$PROJECT_DIR")"
      run_shell_step "Sinkronisasi module Go (go mod tidy)" "cd $q_dir && go mod tidy" || return 1

      BUILD_GO_DEPS_RAN=1
      BUILD_INSTALL_RAN="yes"
      return 0
      ;;
    *)
      die "Target dependency install tidak dikenal: $target"
      ;;
  esac
}

run_step_capture_failure() {
  local title="$1"
  local command_text="$2"
  local output_file="$3"

  local q_out
  q_out="$(to_shell_quoted "$output_file")"
  run_shell_step "$title" "$command_text >$q_out 2>&1"
}

is_node_dependency_error() {
  local output_file="$1"
  grep -Eqi 'MODULE_NOT_FOUND|ERR_MODULE_NOT_FOUND|Cannot find module|Cannot find package|command not found|sh: .*: not found|missing dependencies|npm ERR! code ELSPROBLEMS' "$output_file"
}

is_go_dependency_error() {
  local output_file="$1"
  grep -Eqi 'no required module provides package|missing go.sum entry|go: updates to go.mod needed|cannot find module providing package' "$output_file"
}

retry_build_if_needed() {
  local target="$1"
  local step_title="$2"
  local command_text="$3"
  local fail_message="$4"

  local output_file
  output_file="$(mktemp)"

  if run_step_capture_failure "$step_title" "$command_text" "$output_file"; then
    rm -f "$output_file"
    return 0
  fi

  local should_retry=0
  case "$target" in
    node)
      if [[ "$BUILD_INSTALL_DEPS" != "no" ]] && (( BUILD_NODE_DEPS_INSTALLED == 0 )) && is_node_dependency_error "$output_file"; then
        FORCE_NODE_INSTALL=1
        if run_dependency_install node; then
          should_retry=1
        fi
      fi
      ;;
    go)
      if [[ "$BUILD_INSTALL_DEPS" != "no" ]] && (( BUILD_GO_DEPS_RAN == 0 )) && is_go_dependency_error "$output_file"; then
        FORCE_GO_TIDY=1
        if run_dependency_install go; then
          should_retry=1
        fi
      fi
      ;;
  esac

  if (( should_retry == 1 )); then
    log_warn "$fail_message Mencoba ulang sekali setelah install dependency."
    if run_step_capture_failure "$step_title (retry)" "$command_text" "$output_file"; then
      rm -f "$output_file"
      return 0
    fi
  fi

  cat "$output_file" >&2 || true
  rm -f "$output_file"
  return 1
}

build_go_project() {
  require_command go "Go tidak ditemukan. Install Go dulu."
  require_command pm2 "PM2 tidak ditemukan. Install PM2 dulu."
  BUILD_RUN_MODE="direct"
  BUILD_STRATEGY_FINAL="go-binary"
  BUILD_GO_VERSION="$(go version | awk '{print $3}')"

  if needs_go_mod_tidy; then
    run_dependency_install go || die "go mod tidy gagal."
  fi

  if (( GO_SHOULD_UPDATE_ENV == 1 )); then
    upsert_env_port "$BUILD_ENV_FILE" "$BUILD_PORT"
    log_info "PORT disimpan ke $(basename "$BUILD_ENV_FILE"): $BUILD_PORT"
  fi

  local output_dir="$PROJECT_DIR/.gas/bin"
  mkdir -p "$output_dir"

  local bin_name=""
  bin_name="$(sanitize_binary_name "$BUILD_PM2_NAME")"
  local output_bin="$output_dir/$bin_name"

  log_info "Build Go target: $BUILD_GO_TARGET"
  local q_dir q_bin q_target
  q_dir="$(to_shell_quoted "$PROJECT_DIR")"
  q_bin="$(to_shell_quoted "$output_bin")"
  q_target="$(to_shell_quoted "$BUILD_GO_TARGET")"

  if ! retry_build_if_needed "go" "Build binary Go" "cd $q_dir && go build -o $q_bin $q_target" "go build gagal."; then
    die "go build gagal."
  fi

  BUILD_START_FILE="$output_bin"
  run_pm2_direct "$output_bin" "$BUILD_PM2_NAME" "$BUILD_PORT"
}

resolve_node_port() {
  local detected=""
  detected="$(detect_env_port)"
  local detected_port="${detected%%;*}"
  local env_file="${detected#*;}"
  BUILD_ENV_FILE=""

  local default_port="3000"
  if [[ -n "${BUILD_ECOSYSTEM_DEFAULT_PORT:-}" ]] && validate_port "$BUILD_ECOSYSTEM_DEFAULT_PORT"; then
    default_port="$BUILD_ECOSYSTEM_DEFAULT_PORT"
  elif [[ -n "$detected_port" ]] && validate_port "$detected_port"; then
    default_port="$detected_port"
    BUILD_ENV_FILE="$env_file"
  fi

  resolve_port_input "Port" "$default_port"
}

resolve_build_strategy() {
  if [[ -n "${BUILD_RUN_MODE:-}" ]]; then
    case "$BUILD_RUN_MODE" in
      direct|ecosystem) ;;
      *) die "Nilai --run-mode harus ecosystem atau direct." ;;
    esac
  fi

  if [[ -n "$BUILD_STRATEGY" ]]; then
    case "$BUILD_STRATEGY" in
      auto|ecosystem|node-entry|npm-preview|npm-start) return ;;
      *) die "Nilai --strategy harus auto|ecosystem|node-entry|npm-preview|npm-start" ;;
    esac
  fi

  if [[ -n "$BUILD_SVELTE_STRATEGY" ]]; then
    case "$BUILD_SVELTE_STRATEGY" in
      auto) BUILD_STRATEGY="auto"; return ;;
      ecosystem) BUILD_STRATEGY="ecosystem"; return ;;
      direct|adapter-node) BUILD_STRATEGY="node-entry"; return ;;
      preview) BUILD_STRATEGY="npm-preview"; return ;;
      *)
        die "Nilai --svelte-strategy tidak valid."
        ;;
    esac
  fi

  case "${BUILD_RUN_MODE:-}" in
    direct) BUILD_STRATEGY="node-entry"; return ;;
    ecosystem) BUILD_STRATEGY="ecosystem"; return ;;
  esac

  local default_strategy="auto"
  if [[ "$BUILD_USE_ECOSYSTEM_CONFIG" == "yes" ]]; then
    default_strategy="ecosystem"
  fi

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    if (( GUM_ENABLED == 1 )); then
      gum style --bold "Pilih build strategy"
      gum style "ecosystem  -> pakai/generate ecosystem PM2 config"
      gum style "node-entry -> jalankan entry hasil build langsung pakai node"
      gum style "npm-preview-> jalankan npm run preview"
      gum style "npm-start  -> jalankan npm run start"
      gum style "auto       -> pilih terbaik otomatis"
    else
      printf 'Build strategy:\n' >&2
      printf '  ecosystem  -> pakai/generate ecosystem PM2 config\n' >&2
      printf '  node-entry -> jalankan entry hasil build langsung pakai node\n' >&2
      printf '  npm-preview-> jalankan npm run preview\n' >&2
      printf '  npm-start  -> jalankan npm run start\n' >&2
      printf '  auto       -> pilih terbaik otomatis\n' >&2
    fi
    BUILD_STRATEGY="$(ui_select 'Pilih strategy' "$default_strategy" auto ecosystem node-entry npm-start npm-preview)"
  else
    BUILD_STRATEGY="$default_strategy"
  fi
}


ensure_node_build_ready() {
  if (( SVELTE_BUILD_DONE == 1 )); then
    return 0
  fi

  if [[ ! -f "$PROJECT_DIR/package.json" ]]; then
    log_warn "package.json tidak ditemukan. Skip install/build Node."
    SVELTE_BUILD_DONE=1
    return 0
  fi

  BUILD_NODE_VERSION="$(node -v 2>/dev/null || true)"
  BUILD_NPM_VERSION="$(npm -v 2>/dev/null || true)"

  if needs_node_install; then
    run_dependency_install node || {
      SVELTE_LAST_ERROR="Install dependency Node gagal."
      return 1
    }
  fi

  if package_has_script "build"; then
    local q_dir
    q_dir="$(to_shell_quoted "$PROJECT_DIR")"
    if ! retry_build_if_needed "node" "Menjalankan npm run build" "cd $q_dir && npm run build" "npm run build gagal."; then
      SVELTE_LAST_ERROR="npm run build gagal."
      return 1
    fi
  else
    log_info "Script build tidak ditemukan di package.json, skip npm run build."
  fi

  SVELTE_BUILD_DONE=1
}


run_node_strategy_npm_preview() {
  ensure_node_build_ready || return 1

  if ! package_has_script "preview"; then
    SVELTE_LAST_ERROR="Script npm 'preview' tidak ditemukan."
    return 1
  fi

  local q_name q_dir q_port
  q_name="$(to_shell_quoted "$BUILD_PM2_NAME")"
  q_dir="$(to_shell_quoted "$PROJECT_DIR")"
  q_port="$(to_shell_quoted "$BUILD_PORT")"

  local cmd="PORT=$q_port pm2 start npm --name $q_name --cwd $q_dir -- run preview -- --host 0.0.0.0 --port $q_port"
  pm2_replace_and_start "$cmd" || {
    SVELTE_LAST_ERROR="Gagal menjalankan npm run preview via PM2."
    return 1
  }

  BUILD_START_FILE="npm run preview -- --host 0.0.0.0 --port $BUILD_PORT"
  BUILD_RUN_MODE="npm-preview"
  return 0
}

run_node_strategy_npm_start() {
  ensure_node_build_ready || return 1

  if ! package_has_script "start"; then
    SVELTE_LAST_ERROR="Script npm 'start' tidak ditemukan."
    return 1
  fi

  local q_name q_dir q_port
  q_name="$(to_shell_quoted "$BUILD_PM2_NAME")"
  q_dir="$(to_shell_quoted "$PROJECT_DIR")"
  q_port="$(to_shell_quoted "$BUILD_PORT")"

  local cmd="PORT=$q_port pm2 start npm --name $q_name --cwd $q_dir -- run start"
  pm2_replace_and_start "$cmd" || {
    SVELTE_LAST_ERROR="Gagal menjalankan npm run start via PM2."
    return 1
  }

  BUILD_START_FILE="npm run start"
  BUILD_RUN_MODE="npm-start"
  return 0
}

run_node_strategy_node_entry() {
  ensure_node_build_ready || return 1

  local entry_file=""
  entry_file="$(detect_node_entry_file || true)"
  if [[ -z "$entry_file" ]]; then
    SVELTE_LAST_ERROR="Strategy node-entry gagal: file entry hasil build tidak ditemukan."
    return 1
  fi

  local entry_rel="${entry_file#"$PROJECT_DIR/"}"
  local q_name q_dir q_port q_entry
  q_name="$(to_shell_quoted "$BUILD_PM2_NAME")"
  q_dir="$(to_shell_quoted "$PROJECT_DIR")"
  q_port="$(to_shell_quoted "$BUILD_PORT")"
  q_entry="$(to_shell_quoted "$entry_rel")"

  local cmd="PORT=$q_port pm2 start node --name $q_name --cwd $q_dir -- $q_entry"
  pm2_replace_and_start "$cmd" || {
    SVELTE_LAST_ERROR="Gagal menjalankan entry direct via PM2."
    return 1
  }

  BUILD_START_FILE="$entry_file"
  BUILD_RUN_MODE="node-entry"
  return 0
}

write_ecosystem_file() {
  local app_name="$1"
  local port="$2"
  local mode="$3"
  local start_file="${4:-}"

  local ecosystem_file="$PROJECT_DIR/ecosystem.config.cjs"
  if [[ "$mode" == "node-entry" ]]; then
    local rel_start="$start_file"
    rel_start="${rel_start#"$PROJECT_DIR/"}"
    cat > "$ecosystem_file" <<EOF2
module.exports = {
  apps: [
    {
      name: '${app_name}',
      cwd: '${PROJECT_DIR}',
      script: 'node',
      args: '${rel_start}',
      env: {
        NODE_ENV: 'production',
        PORT: '${port}'
      }
    }
  ]
};
EOF2
  elif [[ "$mode" == "npm-start" ]]; then
    cat > "$ecosystem_file" <<EOF2
module.exports = {
  apps: [
    {
      name: '${app_name}',
      cwd: '${PROJECT_DIR}',
      script: 'npm',
      args: 'run start',
      env: {
        NODE_ENV: 'production',
        PORT: '${port}'
      }
    }
  ]
};
EOF2
  else
    cat > "$ecosystem_file" <<EOF2
module.exports = {
  apps: [
    {
      name: '${app_name}',
      cwd: '${PROJECT_DIR}',
      script: 'npm',
      args: 'run preview -- --host 0.0.0.0 --port ${port}',
      env: {
        NODE_ENV: 'production',
        PORT: '${port}'
      }
    }
  ]
};
EOF2
  fi

  printf '%s\n' "$ecosystem_file"
}

run_node_strategy_ecosystem() {
  ensure_node_build_ready || return 1

  local ecosystem_file="${BUILD_ECOSYSTEM_FILE:-$PROJECT_DIR/ecosystem.config.cjs}"
  local mode="generated"
  local entry_file=""
  local generated_mode=""

  if [[ "$BUILD_USE_ECOSYSTEM_CONFIG" == "yes" && "$BUILD_REUSE_ECOSYSTEM" == "yes" && -f "$ecosystem_file" ]]; then
    if ! has_valid_ecosystem_file; then
      SVELTE_LAST_ERROR="File ecosystem ditemukan tapi tidak valid."
      return 1
    fi
    mode="reused"
  else
    entry_file="$(detect_node_entry_file || true)"
    if [[ -n "$entry_file" ]]; then
      generated_mode="node-entry"
      write_ecosystem_file "$BUILD_PM2_NAME" "$BUILD_PORT" "node-entry" "$entry_file" >/dev/null
    elif package_has_script "start"; then
      generated_mode="npm-start"
      write_ecosystem_file "$BUILD_PM2_NAME" "$BUILD_PORT" "npm-start" >/dev/null
    else
      generated_mode="npm-preview"
      write_ecosystem_file "$BUILD_PM2_NAME" "$BUILD_PORT" "npm-preview" >/dev/null
    fi
    ecosystem_file="$PROJECT_DIR/ecosystem.config.cjs"
    mode="generated"
  fi

  local q_name q_file q_port
  q_name="$(to_shell_quoted "$BUILD_PM2_NAME")"
  q_file="$(to_shell_quoted "$ecosystem_file")"
  q_port="$(to_shell_quoted "$BUILD_PORT")"

  local cmd="PORT=$q_port pm2 start $q_file --only $q_name --update-env"
  pm2_replace_and_start "$cmd" || {
    SVELTE_LAST_ERROR="Gagal menjalankan ecosystem.config.cjs via PM2."
    return 1
  }

  BUILD_ECOSYSTEM_FILE="$ecosystem_file"
  BUILD_ECOSYSTEM_STATE="$mode"
  BUILD_START_FILE="$ecosystem_file"
  if [[ "$mode" == "generated" ]]; then
    BUILD_RUN_MODE="ecosystem-$generated_mode"
  else
    BUILD_RUN_MODE="ecosystem-reused"
  fi
  return 0
}


run_node_strategy_once() {
  local strategy="$1"
  SVELTE_LAST_ERROR=""

  case "$strategy" in
    node-entry)
      run_node_strategy_node_entry
      ;;
    npm-preview)
      run_node_strategy_npm_preview
      ;;
    ecosystem)
      run_node_strategy_ecosystem
      ;;
    npm-start)
      run_node_strategy_npm_start
      ;;
    *)
      SVELTE_LAST_ERROR="Strategy tidak dikenal: $strategy"
      return 1
      ;;
  esac
}

build_node_web_project() {
  require_command node "Node.js tidak ditemukan. Install Node.js dulu."
  require_command npm "npm tidak ditemukan. Install npm dulu."
  require_command pm2 "PM2 tidak ditemukan. Install PM2 dulu."

  local requested_strategy="$BUILD_STRATEGY"
  local final_strategy=""
  local attempted_errors=""

  if [[ "$requested_strategy" != "auto" ]]; then
    if ! run_node_strategy_once "$requested_strategy"; then
      die "${SVELTE_LAST_ERROR:-Strategy $requested_strategy gagal dijalankan.}"
    fi

    if ! verify_runtime_with_feedback; then
      die "Strategy $requested_strategy gagal verifikasi runtime: $BUILD_VERIFY_MESSAGE"
    fi

    final_strategy="$requested_strategy"
  else
    if has_valid_ecosystem_file; then
      if run_node_strategy_once "ecosystem" && verify_runtime_with_feedback; then
        final_strategy="ecosystem"
      else
        attempted_errors+="ecosystem: ${SVELTE_LAST_ERROR:-$BUILD_VERIFY_MESSAGE}; "
      fi
    fi

    if [[ -z "$final_strategy" ]] && package_has_script "start"; then
      if run_node_strategy_once "npm-start" && verify_runtime_with_feedback; then
        final_strategy="npm-start"
      else
        attempted_errors+="npm-start: ${SVELTE_LAST_ERROR:-$BUILD_VERIFY_MESSAGE}; "
      fi
    fi

    if [[ -z "$final_strategy" ]]; then
      if run_node_strategy_once "node-entry" && verify_runtime_with_feedback; then
        final_strategy="node-entry"
      else
        attempted_errors+="node-entry: ${SVELTE_LAST_ERROR:-$BUILD_VERIFY_MESSAGE}; "
      fi
    fi

    if [[ -z "$final_strategy" ]]; then
      if run_node_strategy_once "npm-preview" && verify_runtime_with_feedback; then
        final_strategy="npm-preview"
      else
        attempted_errors+="npm-preview: ${SVELTE_LAST_ERROR:-$BUILD_VERIFY_MESSAGE}; "
      fi
    fi

    if [[ -z "$final_strategy" ]]; then
      die "Semua fallback strategy auto gagal. Detail: $attempted_errors"
    fi
  fi

  BUILD_STRATEGY_FINAL="$final_strategy"
  BUILD_SVELTE_STRATEGY_FINAL="$final_strategy"
}

build_svelte_project() {
  build_node_web_project
}


parse_build_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)
        [[ $# -ge 2 ]] || die "Flag --type butuh nilai."
        BUILD_TYPE="$2"
        shift 2
        ;;
      --type=*)
        BUILD_TYPE="${1#*=}"
        shift
        ;;
      --port)
        [[ $# -ge 2 ]] || die "Flag --port butuh nilai."
        BUILD_PORT="$2"
        shift 2
        ;;
      --port=*)
        BUILD_PORT="${1#*=}"
        shift
        ;;
      --pm2-name)
        [[ $# -ge 2 ]] || die "Flag --pm2-name butuh nilai."
        BUILD_PM2_NAME="$2"
        shift 2
        ;;
      --pm2-name=*)
        BUILD_PM2_NAME="${1#*=}"
        shift
        ;;
      --git-pull)
        [[ $# -ge 2 ]] || die "Flag --git-pull butuh nilai yes|no."
        BUILD_GIT_PULL="$(normalize_yes_no "$2" || true)"
        [[ -n "$BUILD_GIT_PULL" ]] || die "Nilai --git-pull harus yes atau no."
        shift 2
        ;;
      --git-pull=*)
        BUILD_GIT_PULL="$(normalize_yes_no "${1#*=}" || true)"
        [[ -n "$BUILD_GIT_PULL" ]] || die "Nilai --git-pull harus yes atau no."
        shift
        ;;
      --install-deps)
        [[ $# -ge 2 ]] || die "Flag --install-deps butuh nilai auto|yes|no."
        BUILD_INSTALL_DEPS="$2"
        shift 2
        ;;
      --install-deps=*)
        BUILD_INSTALL_DEPS="${1#*=}"
        shift
        ;;
      --run-mode)
        [[ $# -ge 2 ]] || die "Flag --run-mode butuh nilai ecosystem|direct."
        BUILD_RUN_MODE="$2"
        shift 2
        ;;
      --run-mode=*)
        BUILD_RUN_MODE="${1#*=}"
        shift
        ;;
      --strategy)
        [[ $# -ge 2 ]] || die "Flag --strategy butuh nilai."
        BUILD_STRATEGY="$2"
        shift 2
        ;;
      --strategy=*)
        BUILD_STRATEGY="${1#*=}"
        shift
        ;;
      --svelte-strategy)
        [[ $# -ge 2 ]] || die "Flag --svelte-strategy butuh nilai."
        BUILD_SVELTE_STRATEGY="$2"
        shift 2
        ;;
      --svelte-strategy=*)
        BUILD_SVELTE_STRATEGY="${1#*=}"
        shift
        ;;
      --reuse-ecosystem)
        [[ $# -ge 2 ]] || die "Flag --reuse-ecosystem butuh nilai yes|no."
        BUILD_REUSE_ECOSYSTEM="$(normalize_yes_no "$2" || true)"
        [[ -n "$BUILD_REUSE_ECOSYSTEM" ]] || die "Nilai --reuse-ecosystem harus yes atau no."
        shift 2
        ;;
      --reuse-ecosystem=*)
        BUILD_REUSE_ECOSYSTEM="$(normalize_yes_no "${1#*=}" || true)"
        [[ -n "$BUILD_REUSE_ECOSYSTEM" ]] || die "Nilai --reuse-ecosystem harus yes atau no."
        shift
        ;;
      --no-ui)
        NO_UI=1
        shift
        ;;
      --yes|-y)
        ASSUME_YES=1
        shift
        ;;
      --help|-h)
        print_build_help_plain
        exit 0
        ;;
      *)
        die "Flag tidak dikenali: $1"
        ;;
    esac
  done

  case "$BUILD_INSTALL_DEPS" in
    auto|yes|no) ;;
    *) die "Nilai --install-deps harus auto|yes|no." ;;
  esac
}

try_load_saved_build_config() {
  local db_path=""
  db_path="$(ensure_metadata_db || true)"
  if [[ -z "$db_path" ]]; then
    return 1
  fi

  local row=""
  row="$(query_build_config_row "$db_path" "$PROJECT_DIR" 2>/dev/null || true)"
  if [[ -z "$row" ]]; then
    return 1
  fi

  local saved_type saved_pm2 saved_port saved_strategy saved_deps saved_mode
  IFS=$'\t' read -r saved_type saved_pm2 saved_port saved_strategy saved_deps saved_mode <<< "$row"

  if [[ -z "$saved_type" ]]; then
    return 1
  fi

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    if (( GUM_ENABLED == 1 )); then
      gum style --bold "Konfigurasi tersimpan ditemukan untuk folder ini"
      gum style "Stack: $saved_type"
      gum style "PM2 name: $saved_pm2"
      gum style "Port: $saved_port"
      if [[ -n "$saved_strategy" ]]; then
        gum style "Strategy: $saved_strategy"
      fi
      gum style "Deps mode: $saved_deps"
      printf '\n'
    else
      printf 'Konfigurasi tersimpan ditemukan untuk folder ini\n' >&2
      printf '  Stack: %s\n' "$saved_type" >&2
      printf '  PM2 name: %s\n' "$saved_pm2" >&2
      printf '  Port: %s\n' "$saved_port" >&2
      if [[ -n "$saved_strategy" ]]; then
        printf '  Strategy: %s\n' "$saved_strategy" >&2
      fi
      printf '  Deps mode: %s\n' "$saved_deps" >&2
      printf '\n' >&2
    fi

    local reuse_config=""
    reuse_config="$(ui_select 'Pakai konfigurasi ini?' 'yes' yes no)"

    if [[ "$reuse_config" != "yes" ]]; then
      return 1
    fi

    BUILD_TYPE="$saved_type"
    [[ -n "$BUILD_PM2_NAME" ]] || BUILD_PM2_NAME="$saved_pm2"
    [[ -n "$BUILD_PORT" ]] || BUILD_PORT="$saved_port"
    [[ -n "$BUILD_INSTALL_DEPS" ]] || BUILD_INSTALL_DEPS="${saved_deps:-auto}"
    [[ -n "$BUILD_STRATEGY" ]] || BUILD_STRATEGY="$saved_strategy"

    return 0
  fi

  return 1
}

collect_build_inputs() {
  local reusing_config="$1"

  detect_stack
  if [[ "$reusing_config" != "yes" ]]; then
    show_detected_stack
    resolve_build_type
  else
    log_info "Menggunakan konfigurasi tersimpan: $BUILD_TYPE"
  fi

  maybe_git_pull
  detect_ecosystem_file || true
  if [[ -n "$BUILD_ECOSYSTEM_FILE" ]]; then
    parse_ecosystem_defaults "$BUILD_ECOSYSTEM_FILE" || true
    BUILD_ECOSYSTEM_STATE="existing"
    if [[ "$reusing_config" != "yes" ]]; then
      show_ecosystem_detection
      resolve_use_ecosystem_config
    fi
  else
    BUILD_USE_ECOSYSTEM_CONFIG="no"
    BUILD_REUSE_ECOSYSTEM="no"
  fi

  case "$BUILD_TYPE" in
    go)
      [[ -z "$BUILD_STRATEGY" ]] || die "--strategy hanya berlaku untuk --type node-web."
      [[ -z "$BUILD_SVELTE_STRATEGY" ]] || die "--svelte-strategy hanya berlaku untuk --type node-web."
      BUILD_RUN_MODE="direct"
      resolve_pm2_name "${BUILD_ECOSYSTEM_DEFAULT_NAME:-$(basename "$PROJECT_DIR")}"
      resolve_go_port_and_env
      resolve_go_target
      ;;
    node-web)
      if [[ "$reusing_config" != "yes" ]]; then
        resolve_build_strategy
      fi
      resolve_reuse_ecosystem
      resolve_pm2_name "${BUILD_ECOSYSTEM_DEFAULT_NAME:-$(basename "$PROJECT_DIR")}"
      resolve_node_port
      ;;
    *)
      die "Type tidak valid: $BUILD_TYPE"
      ;;
  esac
}

print_build_plan() {
  printf '\n'
  printf 'Rencana build:\n'
  printf '  Folder    : %s\n' "$PROJECT_DIR"
  printf '  Stack     : %s\n' "${BUILD_STACK_LABEL:-Unknown}"
  printf '  Type      : %s\n' "$BUILD_TYPE"
  printf '  Git pull  : %s\n' "${BUILD_GIT_PULL:-no}"
  printf '  Deps mode : %s\n' "${BUILD_INSTALL_DEPS:-auto}"
  printf '  PM2 name  : %s\n' "$BUILD_PM2_NAME"
  printf '  Port      : %s\n' "$BUILD_PORT"
  if [[ "$BUILD_TYPE" == "node-web" ]]; then
    printf '  Strategy  : %s\n' "${BUILD_STRATEGY:-auto}"
    if [[ -n "$BUILD_ECOSYSTEM_FILE" ]]; then
      printf '  Ecosystem : %s\n' "$(basename "$BUILD_ECOSYSTEM_FILE")"
      printf '  Use eco   : %s\n' "${BUILD_USE_ECOSYSTEM_CONFIG:-no}"
      printf '  Reuse eco : %s\n' "${BUILD_REUSE_ECOSYSTEM:-no}"
    fi
  else
    printf '  Run mode  : %s\n' "${BUILD_RUN_MODE:-direct}"
  fi
  if [[ "$BUILD_TYPE" == "go" ]]; then
    printf '  Go target : %s\n' "$BUILD_GO_TARGET"
  fi
  printf '\n'
}

confirm_build_execution() {
  if (( ASSUME_YES == 1 )) || (( UI_ENABLED == 0 )); then
    return 0
  fi

  local proceed=""
  proceed="$(ui_select 'Lanjut eksekusi build dengan konfigurasi di atas?' 'yes' yes no)"
  [[ "$proceed" == "yes" ]]
}

run_build() {
  parse_build_args "$@"
  init_ui_mode

  BUILD_STACK_ID=""
  BUILD_STACK_LABEL=""
  BUILD_STACK_CONFIDENCE=""
  BUILD_STACK_NOTES=""
  BUILD_ECOSYSTEM_FILE=""
  BUILD_ECOSYSTEM_STATE="not-used"
  BUILD_ECOSYSTEM_DEFAULT_NAME=""
  BUILD_ECOSYSTEM_DEFAULT_PORT=""
  BUILD_ECOSYSTEM_DEFAULT_SCRIPT=""
  BUILD_ECOSYSTEM_DEFAULT_ARGS=""
  BUILD_ECOSYSTEM_DEFAULT_CWD=""
  BUILD_USE_ECOSYSTEM_CONFIG=""
  BUILD_STRATEGY_FINAL=""
  BUILD_SVELTE_STRATEGY_FINAL=""
  BUILD_VERIFY_STATUS="not_checked"
  BUILD_VERIFY_MESSAGE="-"
  BUILD_HEALTH_STATUS="skipped"
  BUILD_SVELTE_ECOSYSTEM_MODE="not-used"
  BUILD_INSTALL_RAN="no"
  BUILD_GIT_CHANGED_FILES=""
  BUILD_GIT_PULL_SUCCESS=0
  BUILD_NODE_DEPS_INSTALLED=0
  BUILD_GO_DEPS_RAN=0
  FORCE_NODE_INSTALL=0
  FORCE_GO_TIDY=0
  SVELTE_BUILD_DONE=0
  SVELTE_LAST_ERROR=""

  local reusing_saved_config="no"
  if try_load_saved_build_config; then
    reusing_saved_config="yes"
  fi

  collect_build_inputs "$reusing_saved_config"
  print_build_plan

  if ! confirm_build_execution; then
    printf 'Build dibatalkan.\n'
    return
  fi

  execute_git_pull_if_needed

  case "$BUILD_TYPE" in
    go)
      build_go_project
      if ! verify_runtime_with_feedback; then
        die "Runtime Go gagal diverifikasi: $BUILD_VERIFY_MESSAGE"
      fi
      ;;
    node-web)
      build_node_web_project
      ;;
    *)
      die "Type tidak valid: $BUILD_TYPE"
      ;;
  esac

  write_metadata
  print_build_summary
}
