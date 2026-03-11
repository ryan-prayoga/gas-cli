# shellcheck shell=bash
# Command dispatcher and command handlers.

print_kv_line() {
  local key="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    value="-"
  fi
  printf '%-13s: %s\n' "$key" "$value"
}

metadata_not_found_message() {
  printf 'Project ini belum pernah dibuild menggunakan gas.\n'
}

parse_info_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        print_info_help_plain
        exit 0
        ;;
      --no-ui)
        NO_UI=1
        shift
        ;;
      *)
        die "Flag tidak dikenali untuk 'gas info': $1"
        ;;
    esac
  done
}

parse_list_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        print_list_help_plain
        exit 0
        ;;
      --no-ui)
        NO_UI=1
        shift
        ;;
      *)
        die "Flag tidak dikenali untuk 'gas list': $1"
        ;;
    esac
  done
}

parse_restart_args() {
  RESTART_PM2_NAME=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        print_restart_help_plain
        exit 0
        ;;
      --no-ui)
        NO_UI=1
        shift
        ;;
      --*)
        die "Flag tidak dikenali untuk 'gas restart': $1"
        ;;
      *)
        if [[ -n "$RESTART_PM2_NAME" ]]; then
          die "Argumen terlalu banyak untuk 'gas restart'."
        fi
        RESTART_PM2_NAME="$1"
        shift
        ;;
    esac
  done
}

parse_logs_args() {
  LOGS_PM2_NAME=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        print_logs_help_plain
        exit 0
        ;;
      --no-ui)
        NO_UI=1
        shift
        ;;
      --*)
        die "Flag tidak dikenali untuk 'gas logs': $1"
        ;;
      *)
        if [[ -n "$LOGS_PM2_NAME" ]]; then
          die "Argumen terlalu banyak untuk 'gas logs'."
        fi
        LOGS_PM2_NAME="$1"
        shift
        ;;
    esac
  done
}

parse_rebuild_args() {
  REBUILD_GIT_PULL=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        print_rebuild_help_plain
        exit 0
        ;;
      --no-ui)
        NO_UI=1
        shift
        ;;
      --yes|-y)
        ASSUME_YES=1
        shift
        ;;
      --git-pull)
        [[ $# -ge 2 ]] || die "Flag --git-pull butuh nilai yes|no."
        REBUILD_GIT_PULL="$(normalize_yes_no "$2" || true)"
        [[ -n "$REBUILD_GIT_PULL" ]] || die "Nilai --git-pull harus yes atau no."
        shift 2
        ;;
      --git-pull=*)
        REBUILD_GIT_PULL="$(normalize_yes_no "${1#*=}" || true)"
        [[ -n "$REBUILD_GIT_PULL" ]] || die "Nilai --git-pull harus yes atau no."
        shift
        ;;
      *)
        die "Flag tidak dikenali untuk 'gas rebuild': $1"
        ;;
    esac
  done
}

parse_remove_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        print_remove_help_plain
        exit 0
        ;;
      --no-ui)
        NO_UI=1
        shift
        ;;
      --yes|-y)
        ASSUME_YES=1
        shift
        ;;
      *)
        die "Flag tidak dikenali untuk 'gas remove': $1"
        ;;
    esac
  done
}

parse_doctor_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        print_doctor_help_plain
        exit 0
        ;;
      --no-ui)
        NO_UI=1
        shift
        ;;
      *)
        die "Flag tidak dikenali untuk 'gas doctor': $1"
        ;;
    esac
  done
}

get_db_path_or_warn() {
  local db_path=""
  db_path="$(ensure_metadata_db || true)"
  if [[ -z "$db_path" ]]; then
    return 1
  fi
  printf '%s\n' "$db_path"
}

print_info_output_plain() {
  local project_dir="$1"
  local app_type="$2"
  local pm2_name="$3"
  local port="$4"
  local strategy="$5"
  local deps_mode="$6"
  local updated_at="$7"
  local pm2_status="$8"

  print_kv_line "Folder" "$project_dir"
  print_kv_line "Stack" "$app_type"
  print_kv_line "PM2 name" "$pm2_name"
  print_kv_line "Port" "$port"
  print_kv_line "Strategy" "$strategy"
  print_kv_line "Deps mode" "$deps_mode"
  print_kv_line "Last build" "$updated_at"
  print_kv_line "PM2 status" "$pm2_status"
}

run_info() {
  parse_info_args "$@"
  init_ui_mode

  local db_path=""
  db_path="$(get_db_path_or_warn || true)"
  if [[ -z "$db_path" ]]; then
    metadata_not_found_message
    return
  fi

  local row=""
  row="$(query_info_row "$db_path" "$PROJECT_DIR")"
  if [[ -z "$row" ]]; then
    metadata_not_found_message
    return
  fi

  local project_dir app_type pm2_name port strategy deps_mode updated_at pm2_status
  IFS=$'\t' read -r project_dir app_type pm2_name port strategy deps_mode updated_at <<< "$row"

  pm2_status="$(detect_pm2_status "$pm2_name")"

  if (( UI_ENABLED == 1 )) && (( GUM_ENABLED == 1 )); then
    gum style --bold "Project Info"
    printf '\n'
  else
    printf 'Project Info\n\n'
  fi

  print_info_output_plain "$project_dir" "$app_type" "$pm2_name" "$port" "$strategy" "$deps_mode" "$updated_at" "$pm2_status"
}

print_list_table_plain() {
  local rows="$1"
  printf '%-20s %-12s %-6s %-20s %-50s\n' "PM2 Name" "Stack" "Port" "Updated" "Path"
  printf '%-20s %-12s %-6s %-20s %-50s\n' "--------------------" "------------" "------" "--------------------" "--------------------------------------------------"
  printf '%s\n' "$rows" | awk -F '\t' '
    {
      pm2=$1
      stack=$2
      port=$3
      updated=$4
      path=$5
      if (pm2 == "") pm2="-"
      if (stack == "") stack="-"
      if (port == "") port="-"
      if (updated == "") updated="-"
      if (path == "") path="-"
      printf "%-20.20s %-12.12s %-6.6s %-20.20s %-50.50s\n", pm2, stack, port, updated, path
    }
  '
}

run_list() {
  parse_list_args "$@"
  init_ui_mode

  local db_path=""
  db_path="$(get_db_path_or_warn || true)"
  if [[ -z "$db_path" ]]; then
    printf 'Belum ada project yang dibuild dengan gas.\n'
    return
  fi

  local rows=""
  rows="$(query_list_rows "$db_path")"
  if [[ -z "$rows" ]]; then
    printf 'Belum ada project yang dibuild dengan gas.\n'
    return
  fi

  if (( GUM_ENABLED == 1 )); then
    {
      printf 'PM2 Name\tStack\tPort\tUpdated\tPath\n'
      printf '%s\n' "$rows"
    } | gum table
    return
  fi

  print_list_table_plain "$rows"
}

run_restart() {
  parse_restart_args "$@"
  init_ui_mode

  local pm2_name="$RESTART_PM2_NAME"
  if [[ -z "$pm2_name" ]]; then
    local db_path=""
    db_path="$(get_db_path_or_warn || true)"
    if [[ -z "$db_path" ]]; then
      metadata_not_found_message
      return 1
    fi
    local row=""
    row="$(query_build_config_row "$db_path" "$PROJECT_DIR")"
    if [[ -z "$row" ]]; then
      metadata_not_found_message
      return 1
    fi
    local app_type port strategy deps_mode run_mode
    IFS=$'\t' read -r app_type pm2_name port strategy deps_mode run_mode <<< "$row"
    if [[ -z "$pm2_name" ]]; then
      die "PM2 name tidak ditemukan di metadata project ini."
    fi
  fi

  require_command pm2 "PM2 tidak ditemukan. Install PM2 dulu."

  if ! pm2_app_exists "$pm2_name"; then
    die "PM2 app '$pm2_name' tidak ditemukan."
  fi

  log_info "Restart PM2 app: $pm2_name"
  pm2 restart "$pm2_name"
}

run_logs() {
  parse_logs_args "$@"
  init_ui_mode

  local pm2_name="$LOGS_PM2_NAME"
  if [[ -z "$pm2_name" ]]; then
    local db_path=""
    db_path="$(get_db_path_or_warn || true)"
    if [[ -z "$db_path" ]]; then
      metadata_not_found_message
      return 1
    fi
    local row=""
    row="$(query_build_config_row "$db_path" "$PROJECT_DIR")"
    if [[ -z "$row" ]]; then
      metadata_not_found_message
      return 1
    fi
    local app_type port strategy deps_mode run_mode
    IFS=$'\t' read -r app_type pm2_name port strategy deps_mode run_mode <<< "$row"
    if [[ -z "$pm2_name" ]]; then
      die "PM2 name tidak ditemukan di metadata project ini."
    fi
  fi

  require_command pm2 "PM2 tidak ditemukan. Install PM2 dulu."

  log_info "Menampilkan logs PM2 app: $pm2_name"
  pm2 logs "$pm2_name"
}

run_rebuild() {
  parse_rebuild_args "$@"
  init_ui_mode

  local db_path=""
  db_path="$(get_db_path_or_warn || true)"
  if [[ -z "$db_path" ]]; then
    metadata_not_found_message
    return 1
  fi

  local row=""
  row="$(query_build_config_row "$db_path" "$PROJECT_DIR")"
  if [[ -z "$row" ]]; then
    metadata_not_found_message
    return 1
  fi

  local app_type pm2_name port strategy deps_mode run_mode
  IFS=$'\t' read -r app_type pm2_name port strategy deps_mode run_mode <<< "$row"

  [[ -n "$pm2_name" ]] || die "Metadata tidak valid: pm2_name kosong."

  local type_arg="node-web"
  if [[ "$app_type" == "go" ]]; then
    type_arg="go"
  fi

  local git_pull="${REBUILD_GIT_PULL:-}"
  if [[ -z "$git_pull" ]]; then
    if command_exists git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git_pull="yes"
    else
      git_pull="no"
    fi
  fi

  local -a args=()
  args+=(--type "$type_arg")
  args+=(--pm2-name "$pm2_name")
  if [[ -n "$port" ]]; then
    args+=(--port "$port")
  fi
  args+=(--git-pull "$git_pull")

  if [[ "$type_arg" == "node-web" && -n "$strategy" ]]; then
    args+=(--strategy "$strategy")
  fi

  if [[ -n "$deps_mode" ]]; then
    args+=(--install-deps "$deps_mode")
  fi

  if [[ "$run_mode" == "ecosystem-reused" ]]; then
    args+=(--reuse-ecosystem yes)
  fi

  if (( NO_UI == 1 )); then
    args+=(--no-ui)
  fi
  if (( ASSUME_YES == 1 )); then
    args+=(--yes)
  fi

  log_info "Menjalankan rebuild menggunakan metadata terakhir project ini."
  run_build "${args[@]}"
}

confirm_remove() {
  local pm2_name="$1"
  if (( ASSUME_YES == 1 )) || (( UI_ENABLED == 0 )); then
    return 0
  fi

  if (( GUM_ENABLED == 1 )); then
    gum confirm "Hapus PM2 app '$pm2_name' dan metadata project ini?"
    return
  fi

  local ans=""
  ans="$(ui_select "Hapus PM2 app '$pm2_name' dan metadata project ini?" "no" yes no)"
  [[ "$ans" == "yes" ]]
}

run_remove() {
  parse_remove_args "$@"
  init_ui_mode

  local db_path=""
  db_path="$(get_db_path_or_warn || true)"
  if [[ -z "$db_path" ]]; then
    metadata_not_found_message
    return 1
  fi

  local pm2_name=""
  local row=""
  row="$(query_build_config_row "$db_path" "$PROJECT_DIR")"
  if [[ -z "$row" ]]; then
    metadata_not_found_message
    return 1
  fi
  local app_type port strategy deps_mode run_mode
  IFS=$'\t' read -r app_type pm2_name port strategy deps_mode run_mode <<< "$row"
  if [[ -z "$pm2_name" ]]; then
    die "PM2 name tidak ditemukan di metadata project ini."
  fi

  require_command pm2 "PM2 tidak ditemukan. Install PM2 dulu."

  if ! confirm_remove "$pm2_name"; then
    printf 'Aksi remove dibatalkan.\n'
    return
  fi

  if pm2_app_exists "$pm2_name"; then
    pm2 delete "$pm2_name"
    log_info "PM2 app '$pm2_name' dihapus."
  else
    log_warn "PM2 app '$pm2_name' tidak ditemukan. Lanjut hapus metadata."
  fi

  delete_project_metadata "$db_path" "$PROJECT_DIR"
  printf "Project berhasil dihapus dari metadata gas.\n"
}

print_doctor_row() {
  local name="$1"
  local bin_name="$2"
  local version_cmd="$3"

  if command_exists "$bin_name"; then
    local version=""
    if [[ -n "$version_cmd" ]]; then
      version="$(bash -lc "$version_cmd" 2>/dev/null | head -n 1 || true)"
    fi
    if [[ -n "$version" ]]; then
      printf '%-10s: [ok] %s\n' "$name" "$version"
    else
      printf '%-10s: [ok]\n' "$name"
    fi
  else
    printf '%-10s: [x] not installed\n' "$name"
  fi
}

run_doctor() {
  parse_doctor_args "$@"
  init_ui_mode

  if (( UI_ENABLED == 1 )) && (( GUM_ENABLED == 1 )); then
    gum style --bold "Environment Check"
    printf '\n'
  else
    printf 'Environment Check\n\n'
  fi

  print_doctor_row "node" "node" "node -v"
  print_doctor_row "npm" "npm" "npm -v"
  print_doctor_row "pnpm" "pnpm" "pnpm -v"
  print_doctor_row "yarn" "yarn" "yarn -v"
  print_doctor_row "go" "go" "go version"
  print_doctor_row "pm2" "pm2" "pm2 -v"
  print_doctor_row "sqlite3" "sqlite3" "sqlite3 --version"
  print_doctor_row "gum" "gum" "gum --version"
  print_doctor_row "git" "git" "git --version"
}

main() {
  if [[ $# -eq 0 ]]; then
    print_overview
    exit 0
  fi

  local command="$1"
  shift || true

  case "$command" in
    build)
      run_build "$@"
      ;;
    info)
      run_info "$@"
      ;;
    list)
      run_list "$@"
      ;;
    restart)
      run_restart "$@"
      ;;
    logs)
      run_logs "$@"
      ;;
    rebuild)
      run_rebuild "$@"
      ;;
    remove)
      run_remove "$@"
      ;;
    doctor)
      run_doctor "$@"
      ;;
    help|--help|-h)
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --no-ui) NO_UI=1 ;;
        esac
        shift
      done
      print_help
      ;;
    *)
      die "Perintah tidak dikenal: $command. Coba 'gas help'."
      ;;
  esac
}
