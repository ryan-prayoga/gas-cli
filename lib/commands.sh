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

print_info_output_plain() {
  local project_dir="$1"
  local app_type="$2"
  local pm2_name="$3"
  local port="$4"
  local run_mode="$5"
  local env_file="$6"
  local start_file="$7"
  local node_version="$8"
  local npm_version="$9"
  local go_version="${10}"
  local updated_at="${11}"
  local pm2_status="${12}"

  print_kv_line "Project" "$project_dir"
  print_kv_line "Type" "$app_type"
  print_kv_line "PM2 name" "$pm2_name"
  print_kv_line "PM2 status" "$pm2_status"
  print_kv_line "Port" "$port"
  print_kv_line "Run mode" "$run_mode"
  print_kv_line "Env file" "$env_file"
  print_kv_line "Start file" "$start_file"
  print_kv_line "Node version" "$node_version"
  print_kv_line "NPM version" "$npm_version"
  print_kv_line "Go version" "$go_version"
  print_kv_line "Last build" "$updated_at"
}

run_info() {
  parse_info_args "$@"
  init_ui_mode

  require_sqlite3 || return 1

  local db_path=""
  db_path="$(metadata_db_path)"
  if [[ ! -f "$db_path" ]] || ! db_has_apps_table "$db_path"; then
    printf 'Project ini belum pernah dibuild dengan gas.\n'
    return
  fi

  local row=""
  row="$(query_info_row "$db_path" "$PROJECT_DIR")"
  if [[ -z "$row" ]]; then
    printf 'Project ini belum pernah dibuild dengan gas.\n'
    return
  fi

  local project_dir app_type pm2_name port run_mode env_file start_file
  local node_version npm_version go_version updated_at pm2_status
  IFS=$'\t' read -r project_dir app_type pm2_name port run_mode env_file start_file node_version npm_version go_version updated_at <<< "$row"

  pm2_status="$(detect_pm2_status "$pm2_name")"

  if (( UI_ENABLED == 1 )) && (( GUM_ENABLED == 1 )); then
    gum style --bold "gas info"
    printf '\n'
    print_info_output_plain \
      "$project_dir" "$app_type" "$pm2_name" "$port" "$run_mode" "$env_file" \
      "$start_file" "$node_version" "$npm_version" "$go_version" "$updated_at" "$pm2_status"
    return
  fi

  print_info_output_plain \
    "$project_dir" "$app_type" "$pm2_name" "$port" "$run_mode" "$env_file" \
    "$start_file" "$node_version" "$npm_version" "$go_version" "$updated_at" "$pm2_status"
}

print_list_table_plain() {
  local rows="$1"
  printf '%-40s %-8s %-20s %-6s %-20s\n' "Project" "Type" "PM2 name" "Port" "Updated"
  printf '%-40s %-8s %-20s %-6s %-20s\n' "----------------------------------------" "--------" "--------------------" "------" "--------------------"
  printf '%s\n' "$rows" | awk -F '\t' '
    {
      project=$1
      type=$2
      pm2=$3
      port=$4
      updated=$5
      if (project == "") project="-"
      if (type == "") type="-"
      if (pm2 == "") pm2="-"
      if (port == "") port="-"
      if (updated == "") updated="-"
      printf "%-40.40s %-8.8s %-20.20s %-6.6s %-20.20s\n", project, type, pm2, port, updated
    }
  '
}

run_list() {
  parse_list_args "$@"
  init_ui_mode

  require_sqlite3 || return 1

  local db_path=""
  db_path="$(metadata_db_path)"
  if [[ ! -f "$db_path" ]] || ! db_has_apps_table "$db_path"; then
    printf 'Belum ada project yang dibuild menggunakan gas.\n'
    return
  fi

  local rows=""
  rows="$(query_list_rows "$db_path")"
  if [[ -z "$rows" ]]; then
    printf 'Belum ada project yang dibuild menggunakan gas.\n'
    return
  fi

  if (( GUM_ENABLED == 1 )); then
    {
      printf 'Project\tType\tPM2 name\tPort\tUpdated\n'
      printf '%s\n' "$rows"
    } | gum table
    return
  fi

  print_list_table_plain "$rows"
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
