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

parse_domain_add_args() {
  DOMAIN_ADD_DOMAIN=""
  DOMAIN_ADD_APP=""
  DOMAIN_ADD_PORT=""
  DOMAIN_ADD_SSL=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        print_domain_help_plain
        exit 0
        ;;
      --app)
        [[ $# -ge 2 ]] || die "Flag --app butuh nilai pm2-name."
        DOMAIN_ADD_APP="$2"
        shift 2
        ;;
      --app=*)
        DOMAIN_ADD_APP="${1#*=}"
        shift
        ;;
      --port)
        [[ $# -ge 2 ]] || die "Flag --port butuh nilai."
        DOMAIN_ADD_PORT="$2"
        shift 2
        ;;
      --port=*)
        DOMAIN_ADD_PORT="${1#*=}"
        shift
        ;;
      --ssl)
        [[ $# -ge 2 ]] || die "Flag --ssl butuh nilai yes|no."
        DOMAIN_ADD_SSL="$(normalize_yes_no "$2" || true)"
        [[ -n "$DOMAIN_ADD_SSL" ]] || die "Nilai --ssl harus yes atau no."
        shift 2
        ;;
      --ssl=*)
        DOMAIN_ADD_SSL="$(normalize_yes_no "${1#*=}" || true)"
        [[ -n "$DOMAIN_ADD_SSL" ]] || die "Nilai --ssl harus yes atau no."
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
      --*)
        die "Flag tidak dikenali untuk 'gas domain add': $1"
        ;;
      *)
        if [[ -n "$DOMAIN_ADD_DOMAIN" ]]; then
          die "Argumen terlalu banyak untuk 'gas domain add'."
        fi
        DOMAIN_ADD_DOMAIN="$1"
        shift
        ;;
    esac
  done
}

parse_domain_remove_args() {
  DOMAIN_REMOVE_DOMAIN=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        print_domain_help_plain
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
      --*)
        die "Flag tidak dikenali untuk 'gas domain remove': $1"
        ;;
      *)
        if [[ -n "$DOMAIN_REMOVE_DOMAIN" ]]; then
          die "Argumen terlalu banyak untuk 'gas domain remove'."
        fi
        DOMAIN_REMOVE_DOMAIN="$1"
        shift
        ;;
    esac
  done
}

parse_domain_list_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        print_domain_help_plain
        exit 0
        ;;
      --no-ui)
        NO_UI=1
        shift
        ;;
      --*)
        die "Flag tidak dikenali untuk 'gas domain list': $1"
        ;;
      *)
        die "Argumen tidak dikenali untuk 'gas domain list': $1"
        ;;
    esac
  done
}

confirm_domain_action() {
  local message="$1"
  if (( ASSUME_YES == 1 )) || (( UI_ENABLED == 0 )); then
    return 0
  fi

  if (( GUM_ENABLED == 1 )); then
    gum confirm "$message"
    return
  fi

  local ans=""
  ans="$(ui_select "$message" "yes" yes no)"
  [[ "$ans" == "yes" ]]
}

resolve_domain_target_app() {
  local db_path="$1"
  DOMAIN_SELECTED_PROJECT=""
  DOMAIN_SELECTED_PM2=""
  DOMAIN_SELECTED_PORT=""

  if [[ -n "$DOMAIN_ADD_APP" ]]; then
    local app_row=""
    app_row="$(query_app_by_pm2_name "$db_path" "$DOMAIN_ADD_APP")"
    [[ -n "$app_row" ]] || die "App '$DOMAIN_ADD_APP' tidak ditemukan di metadata gas."

    local app_type
    IFS=$'\t' read -r DOMAIN_SELECTED_PROJECT app_type DOMAIN_SELECTED_PM2 DOMAIN_SELECTED_PORT <<< "$app_row"
  else
    local current_row=""
    current_row="$(query_build_config_row "$db_path" "$PROJECT_DIR")"
    if [[ -n "$current_row" ]]; then
      local app_type strategy deps_mode run_mode
      IFS=$'\t' read -r app_type DOMAIN_SELECTED_PM2 DOMAIN_SELECTED_PORT strategy deps_mode run_mode <<< "$current_row"
      DOMAIN_SELECTED_PROJECT="$PROJECT_DIR"
    fi

    if [[ -n "$DOMAIN_SELECTED_PM2" && -n "$DOMAIN_SELECTED_PORT" ]]; then
      if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
        local use_current=""
        use_current="$(ui_select "Gunakan app dari folder ini? (${DOMAIN_SELECTED_PM2} port ${DOMAIN_SELECTED_PORT})" "yes" yes no)"
        if [[ "$use_current" != "yes" ]]; then
          DOMAIN_SELECTED_PROJECT=""
          DOMAIN_SELECTED_PM2=""
          DOMAIN_SELECTED_PORT=""
        fi
      fi
    fi

    if [[ -z "$DOMAIN_SELECTED_PM2" || -z "$DOMAIN_SELECTED_PORT" ]]; then
      local rows=""
      rows="$(query_apps_candidate_rows "$db_path")"
      [[ -n "$rows" ]] || die "Belum ada metadata app. Jalankan 'gas build' dulu."

      local -a labels=()
      local -a projects=()
      local -a pm2s=()
      local -a ports=()
      while IFS=$'\t' read -r project_dir app_type pm2_name port; do
        [[ -n "$pm2_name" ]] || continue
        labels+=("${pm2_name} (port:${port:-?}) | ${project_dir}")
        projects+=("$project_dir")
        pm2s+=("$pm2_name")
        ports+=("$port")
      done <<< "$rows"

      (( ${#labels[@]} > 0 )) || die "Tidak ada app valid di metadata."

      local selected_label="${labels[0]}"
      if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
        selected_label="$(ui_select 'Pilih app untuk domain ini' "${labels[0]}" "${labels[@]}")"
      fi

      local idx=0
      local found=0
      for idx in "${!labels[@]}"; do
        if [[ "${labels[$idx]}" == "$selected_label" ]]; then
          DOMAIN_SELECTED_PROJECT="${projects[$idx]}"
          DOMAIN_SELECTED_PM2="${pm2s[$idx]}"
          DOMAIN_SELECTED_PORT="${ports[$idx]}"
          found=1
          break
        fi
      done

      if (( found == 0 )); then
        DOMAIN_SELECTED_PROJECT="${projects[0]}"
        DOMAIN_SELECTED_PM2="${pm2s[0]}"
        DOMAIN_SELECTED_PORT="${ports[0]}"
      fi
    fi
  fi

  [[ -n "$DOMAIN_SELECTED_PM2" ]] || die "PM2 app tidak berhasil dipilih."

  if [[ -n "$DOMAIN_ADD_PORT" ]]; then
    validate_port "$DOMAIN_ADD_PORT" || die "Port tidak valid: $DOMAIN_ADD_PORT"
    DOMAIN_SELECTED_PORT="$DOMAIN_ADD_PORT"
  fi

  [[ -n "$DOMAIN_SELECTED_PORT" ]] || die "Port app tidak ditemukan. Gunakan --port <port>."
  validate_port "$DOMAIN_SELECTED_PORT" || die "Port tidak valid: $DOMAIN_SELECTED_PORT"
}

run_domain_add() {
  parse_domain_add_args "$@"
  init_ui_mode

  local db_path=""
  db_path="$(get_db_path_or_warn || true)"
  [[ -n "$db_path" ]] || die "Metadata gas tidak tersedia. Jalankan 'gas build' dulu."

  if [[ -z "$DOMAIN_ADD_DOMAIN" ]]; then
    if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
      DOMAIN_ADD_DOMAIN="$(ui_input 'Domain' '')"
    else
      die "Domain wajib diisi. Gunakan: gas domain add <domain>"
    fi
  fi

  validate_domain_name "$DOMAIN_ADD_DOMAIN" || die "Domain tidak valid: $DOMAIN_ADD_DOMAIN"
  resolve_domain_target_app "$db_path"

  local ssl_choice="${DOMAIN_ADD_SSL:-}"
  if [[ -z "$ssl_choice" ]]; then
    if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
      ssl_choice="$(ui_select 'Install SSL certbot sekarang?' 'no' yes no)"
    else
      ssl_choice="no"
    fi
  fi

  printf '\n'
  printf 'Domain Setup Plan\n'
  print_kv_line "Domain" "$DOMAIN_ADD_DOMAIN"
  print_kv_line "PM2 name" "$DOMAIN_SELECTED_PM2"
  print_kv_line "Port" "$DOMAIN_SELECTED_PORT"
  print_kv_line "SSL" "$ssl_choice"
  printf '\n'

  if ! confirm_domain_action "Lanjut setup domain '$DOMAIN_ADD_DOMAIN'?"; then
    printf 'Aksi domain add dibatalkan.\n'
    return
  fi

  ensure_nginx_installed
  local conf_path=""
  conf_path="$(write_nginx_proxy_config "$DOMAIN_ADD_DOMAIN" "$DOMAIN_SELECTED_PORT")"
  enable_nginx_site "$DOMAIN_ADD_DOMAIN"
  nginx_test_and_reload

  if [[ "$ssl_choice" == "yes" ]]; then
    install_domain_ssl_certbot "$DOMAIN_ADD_DOMAIN"
  fi

  upsert_domain_metadata \
    "$db_path" \
    "$DOMAIN_ADD_DOMAIN" \
    "${DOMAIN_SELECTED_PROJECT:-$PROJECT_DIR}" \
    "$DOMAIN_SELECTED_PM2" \
    "$DOMAIN_SELECTED_PORT" \
    "$conf_path" \
    "$ssl_choice"

  printf "Domain '%s' berhasil disetup ke app '%s' (port %s).\n" \
    "$DOMAIN_ADD_DOMAIN" "$DOMAIN_SELECTED_PM2" "$DOMAIN_SELECTED_PORT"
}

print_domain_list_table_plain() {
  local rows="$1"
  printf '%-28s %-20s %-6s %-5s %-20s %-50s\n' "Domain" "PM2 Name" "Port" "SSL" "Updated" "Path"
  printf '%-28s %-20s %-6s %-5s %-20s %-50s\n' "----------------------------" "--------------------" "------" "-----" "--------------------" "--------------------------------------------------"
  printf '%s\n' "$rows" | awk -F '\t' '
    {
      d=$1; p=$2; port=$3; ssl=$4; u=$5; path=$6
      if (d=="") d="-"; if (p=="") p="-"; if (port=="") port="-";
      if (ssl=="") ssl="-"; if (u=="") u="-"; if (path=="") path="-";
      printf "%-28.28s %-20.20s %-6.6s %-5.5s %-20.20s %-50.50s\n", d, p, port, ssl, u, path
    }
  '
}

run_domain_list() {
  parse_domain_list_args "$@"
  init_ui_mode

  local db_path=""
  db_path="$(get_db_path_or_warn || true)"
  [[ -n "$db_path" ]] || {
    printf 'Belum ada domain yang dikelola gas.\n'
    return
  }

  local rows=""
  rows="$(query_domain_rows "$db_path")"
  if [[ -z "$rows" ]]; then
    printf 'Belum ada domain yang dikelola gas.\n'
    return
  fi

  if (( GUM_ENABLED == 1 )); then
    {
      printf 'Domain\tPM2 Name\tPort\tSSL\tUpdated\tPath\n'
      printf '%s\n' "$rows"
    } | gum table
    return
  fi

  print_domain_list_table_plain "$rows"
}

run_domain_remove() {
  parse_domain_remove_args "$@"
  init_ui_mode

  local db_path=""
  db_path="$(get_db_path_or_warn || true)"
  [[ -n "$db_path" ]] || die "Belum ada domain yang dikelola gas."

  if [[ -z "$DOMAIN_REMOVE_DOMAIN" ]]; then
    local rows=""
    rows="$(query_domain_rows "$db_path")"
    [[ -n "$rows" ]] || die "Belum ada domain yang dikelola gas."

    if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
      local -a domains=()
      while IFS=$'\t' read -r domain pm2_name port ssl_enabled updated_at project_dir; do
        [[ -n "$domain" ]] && domains+=("$domain")
      done <<< "$rows"
      (( ${#domains[@]} > 0 )) || die "Belum ada domain yang dikelola gas."
      DOMAIN_REMOVE_DOMAIN="$(ui_select 'Pilih domain yang mau dihapus' "${domains[0]}" "${domains[@]}")"
    else
      die "Domain wajib diisi. Gunakan: gas domain remove <domain>"
    fi
  fi

  validate_domain_name "$DOMAIN_REMOVE_DOMAIN" || die "Domain tidak valid: $DOMAIN_REMOVE_DOMAIN"

  if ! confirm_domain_action "Hapus domain '$DOMAIN_REMOVE_DOMAIN' dari nginx?"; then
    printf 'Aksi domain remove dibatalkan.\n'
    return
  fi

  ensure_nginx_installed
  remove_nginx_site "$DOMAIN_REMOVE_DOMAIN"
  nginx_test_and_reload
  delete_domain_metadata "$db_path" "$DOMAIN_REMOVE_DOMAIN"

  printf "Domain '%s' berhasil dihapus.\n" "$DOMAIN_REMOVE_DOMAIN"
}

run_domain() {
  local subcommand="${1:-help}"
  if [[ $# -gt 0 ]]; then
    shift
  fi

  case "$subcommand" in
    add)
      run_domain_add "$@"
      ;;
    remove|rm|delete)
      run_domain_remove "$@"
      ;;
    list|ls)
      run_domain_list "$@"
      ;;
    help|--help|-h)
      print_domain_help_plain
      ;;
    *)
      die "Subcommand domain tidak dikenal: $subcommand. Gunakan 'gas domain --help'."
      ;;
  esac
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
    domain)
      run_domain "$@"
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
