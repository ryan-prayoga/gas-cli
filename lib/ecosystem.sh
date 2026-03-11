# shellcheck shell=bash
# Ecosystem/PM2 config detection and generation.

detect_ecosystem_file() {
  local candidates=(
    "$PROJECT_DIR/ecosystem.config.cjs"
    "$PROJECT_DIR/ecosystem.config.js"
    "$PROJECT_DIR/pm2.config.cjs"
    "$PROJECT_DIR/pm2.config.js"
  )
  local file=""
  BUILD_ECOSYSTEM_FILE=""
  for file in "${candidates[@]}"; do
    if [[ -f "$file" ]]; then
      BUILD_ECOSYSTEM_FILE="$file"
      return 0
    fi
  done
  return 1
}

extract_ecosystem_value() {
  local file="$1"
  local key="$2"
  local match=""
  match="$(grep -Eom1 "${key}[[:space:]]*:[[:space:]]*['\"][^'\"]+['\"]" "$file" || true)"
  if [[ -z "$match" ]]; then
    printf '\n'
    return
  fi
  printf '%s\n' "$match" | sed -E "s/^[^:]*:[[:space:]]*['\"]([^'\"]+)['\"].*$/\\1/"
}

extract_ecosystem_port() {
  local file="$1"
  local match=""
  match="$(grep -Eom1 "PORT[[:space:]]*:[[:space:]]*['\"]?[0-9]{2,5}['\"]?" "$file" || true)"
  if [[ -z "$match" ]]; then
    printf '\n'
    return
  fi
  printf '%s\n' "$match" | sed -E 's/.*PORT[[:space:]]*:[[:space:]]*['\''"]?([0-9]{2,5})['\''"]?.*/\1/'
}

extract_port_from_args() {
  local args_value="$1"
  printf '%s\n' "$args_value" | sed -nE "s/.*--port[[:space:]]+([0-9]{2,5}).*/\\1/p" | head -n 1
}

parse_ecosystem_defaults() {
  local file="$1"
  BUILD_ECOSYSTEM_DEFAULT_NAME=""
  BUILD_ECOSYSTEM_DEFAULT_PORT=""
  BUILD_ECOSYSTEM_DEFAULT_SCRIPT=""
  BUILD_ECOSYSTEM_DEFAULT_ARGS=""
  BUILD_ECOSYSTEM_DEFAULT_CWD=""

  [[ -f "$file" ]] || return 1

  BUILD_ECOSYSTEM_DEFAULT_NAME="$(extract_ecosystem_value "$file" "name")"
  BUILD_ECOSYSTEM_DEFAULT_SCRIPT="$(extract_ecosystem_value "$file" "script")"
  BUILD_ECOSYSTEM_DEFAULT_ARGS="$(extract_ecosystem_value "$file" "args")"
  BUILD_ECOSYSTEM_DEFAULT_CWD="$(extract_ecosystem_value "$file" "cwd")"
  BUILD_ECOSYSTEM_DEFAULT_PORT="$(extract_ecosystem_port "$file")"

  if [[ -z "$BUILD_ECOSYSTEM_DEFAULT_PORT" && -n "$BUILD_ECOSYSTEM_DEFAULT_ARGS" ]]; then
    BUILD_ECOSYSTEM_DEFAULT_PORT="$(extract_port_from_args "$BUILD_ECOSYSTEM_DEFAULT_ARGS" || true)"
  fi

  return 0
}

show_ecosystem_detection() {
  if [[ -z "$BUILD_ECOSYSTEM_FILE" ]]; then
    return
  fi

  local file_base
  file_base="$(basename "$BUILD_ECOSYSTEM_FILE")"

  if (( UI_ENABLED == 1 )) && (( GUM_ENABLED == 1 )); then
    gum style --bold "Ecosystem config ditemukan: $file_base"
    gum style "name=${BUILD_ECOSYSTEM_DEFAULT_NAME:-?} port=${BUILD_ECOSYSTEM_DEFAULT_PORT:-?} script=${BUILD_ECOSYSTEM_DEFAULT_SCRIPT:-?}"
  else
    printf 'Ecosystem config ditemukan: %s\n' "$file_base"
    printf '  name  : %s\n' "${BUILD_ECOSYSTEM_DEFAULT_NAME:-unknown}"
    printf '  port  : %s\n' "${BUILD_ECOSYSTEM_DEFAULT_PORT:-unknown}"
    printf '  script: %s\n' "${BUILD_ECOSYSTEM_DEFAULT_SCRIPT:-unknown}"
  fi
}

resolve_use_ecosystem_config() {
  BUILD_USE_ECOSYSTEM_CONFIG="no"
  if [[ -z "$BUILD_ECOSYSTEM_FILE" ]]; then
    BUILD_REUSE_ECOSYSTEM="no"
    return
  fi

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    BUILD_USE_ECOSYSTEM_CONFIG="$(ui_select 'Mau build/run pakai ecosystem config ini?' 'yes' yes no)"
  else
    BUILD_USE_ECOSYSTEM_CONFIG="yes"
  fi

  if [[ "$BUILD_USE_ECOSYSTEM_CONFIG" == "yes" ]]; then
    if [[ -z "$BUILD_REUSE_ECOSYSTEM" ]]; then
      BUILD_REUSE_ECOSYSTEM="yes"
    fi
  else
    if [[ -z "$BUILD_REUSE_ECOSYSTEM" ]]; then
      BUILD_REUSE_ECOSYSTEM="no"
    fi
  fi
}


resolve_reuse_ecosystem() {
  if [[ -z "$BUILD_ECOSYSTEM_FILE" ]]; then
    BUILD_REUSE_ECOSYSTEM="no"
    return
  fi

  if [[ "${BUILD_USE_ECOSYSTEM_CONFIG:-no}" != "yes" ]]; then
    BUILD_REUSE_ECOSYSTEM="no"
    return
  fi

  if [[ -n "$BUILD_REUSE_ECOSYSTEM" ]]; then
    case "$BUILD_REUSE_ECOSYSTEM" in
      yes|no) return ;;
      *) die "Nilai --reuse-ecosystem harus yes atau no" ;;
    esac
  fi

  if [[ "$BUILD_STRATEGY" != "ecosystem" && "$BUILD_STRATEGY" != "auto" ]]; then
    BUILD_REUSE_ECOSYSTEM="no"
    return
  fi

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    BUILD_REUSE_ECOSYSTEM="$(ui_select 'Reuse ecosystem config yang ditemukan?' 'yes' yes no)"
  else
    BUILD_REUSE_ECOSYSTEM="yes"
  fi
}


has_valid_ecosystem_file() {
  [[ -n "$BUILD_ECOSYSTEM_FILE" && -f "$BUILD_ECOSYSTEM_FILE" ]] || return 1
  grep -Eq 'apps[[:space:]]*:' "$BUILD_ECOSYSTEM_FILE"
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
    cat > "$ecosystem_file" <<EOF
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
EOF
  elif [[ "$mode" == "npm-start" ]]; then
    cat > "$ecosystem_file" <<EOF
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
EOF
  else
    cat > "$ecosystem_file" <<EOF
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
EOF
  fi

  printf '%s\n' "$ecosystem_file"
}

