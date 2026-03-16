# shellcheck shell=bash
# Deploy wizard + nginx deployment helpers.

init_deploy_state() {
  DEPLOY_SUBCOMMAND="add"
  DEPLOY_SERVER_TYPE=""
  DEPLOY_MODE=""
  DEPLOY_MAIN_DOMAIN=""
  DEPLOY_PRIMARY_DOMAIN=""
  DEPLOY_CANONICAL=""
  DEPLOY_CANONICAL_HOST=""
  DEPLOY_WWW_MODE=""
  DEPLOY_ADDITIONAL_ALIASES=""
  DEPLOY_APP_NAME=""
  DEPLOY_FRONTEND_APP=""
  DEPLOY_BACKEND_APP=""
  DEPLOY_APP_PORT_OVERRIDE=""
  DEPLOY_UPSTREAM_HOST="127.0.0.1"
  DEPLOY_SSL_MODE=""
  DEPLOY_SSL_CERT=""
  DEPLOY_SSL_KEY=""
  DEPLOY_SSL_PARAMS=""
  DEPLOY_HTTP2="yes"
  DEPLOY_FORCE_HTTPS=""
  DEPLOY_WEBSOCKET=""
  DEPLOY_CLIENT_MAX_BODY_SIZE=""
  DEPLOY_PROXY_TIMEOUT=""
  DEPLOY_GZIP_MODE="on"
  DEPLOY_SECURITY_HEADERS="basic"
  DEPLOY_STATIC_CACHE="basic"
  DEPLOY_ACCESS_LOG="yes"
  DEPLOY_ERROR_LOG_PATH=""
  DEPLOY_CUSTOM_ERROR_ROOT=""
  DEPLOY_VERIFY="yes"
  DEPLOY_VERIFY_UPSTREAM="yes"
  DEPLOY_VERIFY_DOMAIN="yes"
  DEPLOY_PREVIEW_BEFORE_WRITE=""
  DEPLOY_SAVE_PREVIEW_PATH=""
  DEPLOY_DRY_RUN=0
  DEPLOY_PREVIEW_ONLY=0
  DEPLOY_BACKUP="yes"
  DEPLOY_KEEP_ROLLBACK="yes"
  DEPLOY_TEST_CONFIG="yes"
  DEPLOY_RELOAD="yes"
  DEPLOY_REUSE_EXISTING=""
  DEPLOY_CATCHALL="no"
  DEPLOY_CATCHALL_HTTPS="no"
  DEPLOY_DISABLE_DEFAULT_SITE="no"
  DEPLOY_DOMAIN_REMOVE=""
  DEPLOY_REMOVE_ENABLED="yes"
  DEPLOY_REMOVE_CONFIG="yes"
  DEPLOY_REMOVE_RELOAD="yes"
  DEPLOY_REMOVE_TEST="yes"
  DEPLOY_UPLOADS_PATH=""
  DEPLOY_UPLOADS_CACHE=""
  DEPLOY_STATIC_ROOT=""
  DEPLOY_REDIRECT_TARGET=""
  DEPLOY_REDIRECT_CODE="301"
  DEPLOY_MAINTENANCE_ROOT=""
  DEPLOY_GENERATE_MAINTENANCE="no"
  DEPLOY_NOTES=""
  DEPLOY_LOCATION_SPECS=()
  DEPLOY_LOCATION_RAW_SPECS=()
  DEPLOY_ALIAS_DOMAINS=()
  DEPLOY_ROUTE_SUMMARY=()
  DEPLOY_APPS_PROJECT=()
  DEPLOY_APPS_TYPE=()
  DEPLOY_APPS_PM2=()
  DEPLOY_APPS_PORT=()
  DEPLOY_APPS_LABEL=()
  DEPLOY_PRIMARY_PROJECT_DIR=""
  DEPLOY_PRIMARY_PM2_NAME=""
  DEPLOY_PRIMARY_PORT=""
}

deploy_line() {
  local __var_name="$1"
  local __text="$2"
  printf -v "$__var_name" '%s%s\n' "${!__var_name}" "$__text"
}

deploy_lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

deploy_trim() {
  printf '%s' "${1:-}" | awk '{ gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0); print }'
}

deploy_csv_contains() {
  local needle="$1"
  shift || true
  local item=""
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

deploy_array_to_csv() {
  local result=""
  local item=""
  for item in "$@"; do
    [[ -n "$item" ]] || continue
    if [[ -n "$result" ]]; then
      result+=","
    fi
    result+="$item"
  done
  printf '%s\n' "$result"
}

deploy_add_alias_domain() {
  local alias_domain
  alias_domain="$(deploy_trim "$1")"
  [[ -n "$alias_domain" ]] || return 0
  validate_domain_name "$alias_domain" || die "Domain alias tidak valid: $alias_domain"
  if [[ -n "$DEPLOY_PRIMARY_DOMAIN" && "$alias_domain" == "$DEPLOY_PRIMARY_DOMAIN" ]]; then
    return 0
  fi
  if deploy_csv_contains "$alias_domain" "${DEPLOY_ALIAS_DOMAINS[@]-}"; then
    return 0
  fi
  DEPLOY_ALIAS_DOMAINS+=("$alias_domain")
}

deploy_domain_without_www() {
  local domain="$1"
  if [[ "$domain" == www.* ]]; then
    printf '%s\n' "${domain#www.}"
    return
  fi
  printf '%s\n' "$domain"
}

deploy_default_www_host() {
  local base_domain="$1"
  if [[ "$base_domain" == www.* ]]; then
    printf '%s\n' "$base_domain"
    return
  fi
  printf 'www.%s\n' "$base_domain"
}

deploy_finalize_domains() {
  validate_domain_name "$DEPLOY_MAIN_DOMAIN" || die "Domain tidak valid: $DEPLOY_MAIN_DOMAIN"

  local base_domain
  base_domain="$(deploy_domain_without_www "$DEPLOY_MAIN_DOMAIN")"
  local www_domain
  www_domain="$(deploy_default_www_host "$base_domain")"

  case "$DEPLOY_CANONICAL" in
    apex)
      DEPLOY_PRIMARY_DOMAIN="$base_domain"
      ;;
    www)
      DEPLOY_PRIMARY_DOMAIN="$www_domain"
      ;;
    custom)
      [[ -n "$DEPLOY_CANONICAL_HOST" ]] || die "Canonical host custom butuh nilai --canonical-host."
      validate_domain_name "$DEPLOY_CANONICAL_HOST" || die "Canonical host tidak valid: $DEPLOY_CANONICAL_HOST"
      DEPLOY_PRIMARY_DOMAIN="$DEPLOY_CANONICAL_HOST"
      ;;
    none|"")
      DEPLOY_PRIMARY_DOMAIN="$DEPLOY_MAIN_DOMAIN"
      DEPLOY_CANONICAL="none"
      ;;
    *)
      die "Canonical host tidak dikenali: $DEPLOY_CANONICAL"
      ;;
  esac

  DEPLOY_ALIAS_DOMAINS=()
  if [[ "$DEPLOY_MAIN_DOMAIN" != "$DEPLOY_PRIMARY_DOMAIN" ]]; then
    DEPLOY_ALIAS_DOMAINS+=("$DEPLOY_MAIN_DOMAIN")
  fi

  if [[ "$DEPLOY_WWW_MODE" == "yes" ]]; then
    if [[ "$DEPLOY_PRIMARY_DOMAIN" == "$base_domain" ]]; then
      deploy_add_alias_domain "$www_domain"
    elif [[ "$DEPLOY_PRIMARY_DOMAIN" == "$www_domain" ]]; then
      deploy_add_alias_domain "$base_domain"
    else
      deploy_add_alias_domain "$www_domain"
    fi
  fi

  local item=""
  if [[ -n "${DEPLOY_ADDITIONAL_ALIASES:-}" ]]; then
    while IFS= read -r item; do
      deploy_add_alias_domain "$item"
    done < <(printf '%s\n' "$DEPLOY_ADDITIONAL_ALIASES" | tr ',' '\n')
  fi

  if [[ "$DEPLOY_CANONICAL" == "custom" && "$DEPLOY_CANONICAL_HOST" != "$DEPLOY_PRIMARY_DOMAIN" ]]; then
    deploy_add_alias_domain "$DEPLOY_CANONICAL_HOST"
  fi
}

deploy_all_domains() {
  printf '%s\n' "$DEPLOY_PRIMARY_DOMAIN"
  local item=""
  for item in "${DEPLOY_ALIAS_DOMAINS[@]-}"; do
    [[ -n "$item" ]] && printf '%s\n' "$item"
  done
}

deploy_server_name_line() {
  local names=("$DEPLOY_PRIMARY_DOMAIN")
  local item=""
  for item in "${DEPLOY_ALIAS_DOMAINS[@]-}"; do
    [[ -n "$item" ]] && names+=("$item")
  done
  printf '%s\n' "${names[*]}"
}

deploy_find_app_index_by_pm2() {
  local pm2_name="$1"
  local idx
  for idx in "${!DEPLOY_APPS_PM2[@]}"; do
    if [[ "${DEPLOY_APPS_PM2[$idx]}" == "$pm2_name" ]]; then
      printf '%s\n' "$idx"
      return 0
    fi
  done
  return 1
}

deploy_load_apps() {
  local db_path="$1"
  DEPLOY_APPS_PROJECT=()
  DEPLOY_APPS_TYPE=()
  DEPLOY_APPS_PM2=()
  DEPLOY_APPS_PORT=()
  DEPLOY_APPS_LABEL=()

  local rows=""
  rows="$(query_apps_candidate_rows "$db_path")"
  [[ -n "$rows" ]] || die "Belum ada metadata app. Jalankan 'gas build' dulu."

  local -a current_labels=()
  local -a other_labels=()
  local project_dir app_type pm2_name port
  while IFS=$'\t' read -r project_dir app_type pm2_name port; do
    [[ -n "$pm2_name" ]] || continue
    local label="${pm2_name} (port:${port:-?}) | ${app_type:-unknown} | ${project_dir}"
    if [[ "$project_dir" == "$PROJECT_DIR" ]]; then
      current_labels+=("$project_dir"$'\t'"$app_type"$'\t'"$pm2_name"$'\t'"$port"$'\t'"$label")
    else
      other_labels+=("$project_dir"$'\t'"$app_type"$'\t'"$pm2_name"$'\t'"$port"$'\t'"$label")
    fi
  done <<< "$rows"

  local -a ordered=()
  if (( ${#current_labels[@]} > 0 )); then
    ordered+=("${current_labels[@]}")
  fi
  if (( ${#other_labels[@]} > 0 )); then
    ordered+=("${other_labels[@]}")
  fi
  local row=""
  for row in "${ordered[@]}"; do
    IFS=$'\t' read -r project_dir app_type pm2_name port label <<< "$row"
    DEPLOY_APPS_PROJECT+=("$project_dir")
    DEPLOY_APPS_TYPE+=("$app_type")
    DEPLOY_APPS_PM2+=("$pm2_name")
    DEPLOY_APPS_PORT+=("$port")
    DEPLOY_APPS_LABEL+=("$label")
  done

  (( ${#DEPLOY_APPS_PM2[@]} > 0 )) || die "Metadata app kosong atau tidak valid."
}

deploy_select_app_pm2() {
  local prompt="$1"
  local default_pm2="$2"

  local default_label="${DEPLOY_APPS_LABEL[0]}"
  if [[ -n "$default_pm2" ]]; then
    local default_idx=""
    default_idx="$(deploy_find_app_index_by_pm2 "$default_pm2" || true)"
    if [[ -n "$default_idx" ]]; then
      default_label="${DEPLOY_APPS_LABEL[$default_idx]}"
    fi
  fi

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    local choice
    choice="$(ui_select "$prompt" "$default_label" "${DEPLOY_APPS_LABEL[@]-}")"
    local idx
    for idx in "${!DEPLOY_APPS_LABEL[@]}"; do
      if [[ "${DEPLOY_APPS_LABEL[$idx]}" == "$choice" ]]; then
        printf '%s\n' "${DEPLOY_APPS_PM2[$idx]}"
        return 0
      fi
    done
  fi

  if [[ -n "$default_pm2" ]]; then
    printf '%s\n' "$default_pm2"
    return 0
  fi
  printf '%s\n' "${DEPLOY_APPS_PM2[0]}"
}

deploy_resolve_app_record() {
  local pm2_name="$1"
  local idx=""
  idx="$(deploy_find_app_index_by_pm2 "$pm2_name" || true)"
  [[ -n "$idx" ]] || die "App '$pm2_name' tidak ditemukan di metadata gas."
  printf '%s\t%s\t%s\t%s\n' \
    "${DEPLOY_APPS_PROJECT[$idx]}" \
    "${DEPLOY_APPS_TYPE[$idx]}" \
    "${DEPLOY_APPS_PM2[$idx]}" \
    "${DEPLOY_APPS_PORT[$idx]}"
}

deploy_pick_default_mode() {
  if [[ -n "$DEPLOY_MODE" ]]; then
    return
  fi

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    printf '\nMode deploy yang tersedia:\n'
    printf '  - single-app             Semua request / diarahkan ke satu app/upstream.\n'
    printf '  - frontend-backend-split Route / ke frontend dan /api/ ke backend.\n'
    printf '  - custom-multi-location  Tambah location block satu per satu.\n'
    printf '  - static-only            Serve file static dari root/alias.\n'
    printf '  - redirect-only          Domain ini hanya redirect ke target lain.\n'
    printf '  - maintenance            Tampilkan halaman maintenance statis.\n'
    DEPLOY_MODE="$(ui_select "Pilih mode deploy" "single-app" \
      single-app frontend-backend-split custom-multi-location static-only redirect-only maintenance)"
  else
    DEPLOY_MODE="single-app"
  fi
}

deploy_pick_server_type() {
  if [[ -n "$DEPLOY_SERVER_TYPE" ]]; then
    return
  fi

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    printf '\nWeb server:\n'
    printf '  - nginx   Supported, fokus utama untuk gas deploy.\n'
    printf '  - apache  Future / not yet supported.\n'
    DEPLOY_SERVER_TYPE="$(ui_select "Pilih web server" "nginx" nginx apache)"
  else
    DEPLOY_SERVER_TYPE="nginx"
  fi
}

deploy_should_use_proxy_defaults() {
  case "$DEPLOY_MODE" in
    single-app|frontend-backend-split|custom-multi-location)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

deploy_default_bool() {
  local current_value="$1"
  local fallback="$2"
  if [[ -n "$current_value" ]]; then
    printf '%s\n' "$current_value"
  else
    printf '%s\n' "$fallback"
  fi
}

deploy_ensure_global_defaults() {
  if deploy_should_use_proxy_defaults; then
    DEPLOY_WEBSOCKET="$(deploy_default_bool "$DEPLOY_WEBSOCKET" "yes")"
  else
    DEPLOY_WEBSOCKET="$(deploy_default_bool "$DEPLOY_WEBSOCKET" "no")"
  fi

  if [[ "$DEPLOY_SSL_MODE" == "none" ]]; then
    DEPLOY_FORCE_HTTPS="$(deploy_default_bool "$DEPLOY_FORCE_HTTPS" "no")"
  else
    DEPLOY_FORCE_HTTPS="$(deploy_default_bool "$DEPLOY_FORCE_HTTPS" "yes")"
  fi

  if [[ -z "$DEPLOY_PREVIEW_BEFORE_WRITE" ]]; then
    DEPLOY_PREVIEW_BEFORE_WRITE="yes"
  fi
}

deploy_add_route_summary() {
  DEPLOY_ROUTE_SUMMARY+=("$1")
}

deploy_add_location_spec() {
  DEPLOY_LOCATION_SPECS+=("$1")
}

deploy_parse_proxy_target() {
  local target="$1"
  local host="$DEPLOY_UPSTREAM_HOST"
  local port=""
  local label=""
  local project_dir=""

  local app_row=""
  app_row="$(deploy_resolve_app_record "$target" 2>/dev/null || true)"
  if [[ -n "$app_row" ]]; then
    local app_type
    IFS=$'\t' read -r project_dir app_type label port <<< "$app_row"
    printf 'app\t%s\t%s\t%s\t%s\n' "$project_dir" "$label" "$host" "$port"
    return 0
  fi

  if [[ "$target" =~ ^[^:]+:[0-9]+$ ]]; then
    host="${target%:*}"
    port="${target##*:}"
    validate_port "$port" || die "Port proxy manual tidak valid: $port"
    printf 'manual\t\t%s\t%s\t%s\n' "$target" "$target" "$port"
    return 0
  fi

  die "Target proxy tidak dikenali: $target"
}

deploy_materialize_location_cli() {
  local spec="$1"
  [[ "$spec" == *=* ]] || die "Format --location harus <path>=<tipe>:<target>."

  local path="${spec%%=*}"
  local action="${spec#*=}"
  [[ "$path" == /* ]] || die "Path location harus diawali '/': $path"
  [[ "$action" == *:* ]] || die "Format location tidak valid: $spec"

  local type="${action%%:*}"
  local remainder="${action#*:}"

  case "$type" in
    proxy)
      local kind project_dir pm2_name host port
      IFS=$'\t' read -r kind project_dir pm2_name host port <<< "$(deploy_parse_proxy_target "$remainder")"
      deploy_add_location_spec "proxy|$path|$kind|$project_dir|$pm2_name|$host|$port"
      if [[ "$kind" == "app" ]]; then
        deploy_add_route_summary "$path -> $pm2_name ($host:$port)"
      else
        deploy_add_route_summary "$path -> $host"
      fi
      ;;
    alias)
      deploy_add_location_spec "alias|$path|$remainder"
      deploy_add_route_summary "$path -> alias:$remainder"
      ;;
    root)
      deploy_add_location_spec "root|$path|$remainder"
      deploy_add_route_summary "$path -> root:$remainder"
      ;;
    redirect)
      local code="$DEPLOY_REDIRECT_CODE"
      local target="$remainder"
      if [[ "$remainder" =~ ^[0-9]{3}:.+$ ]]; then
        code="${remainder%%:*}"
        target="${remainder#*:}"
      fi
      deploy_add_location_spec "redirect|$path|$code|$target"
      deploy_add_route_summary "$path -> redirect:$target ($code)"
      ;;
    return)
      local code body
      code="${remainder%%:*}"
      body="${remainder#*:}"
      [[ "$code" =~ ^[0-9]{3}$ ]] || die "Format return harus return:<code>:<text>"
      deploy_add_location_spec "return|$path|$code|$body"
      deploy_add_route_summary "$path -> return $code"
      ;;
    *)
      die "Tipe location tidak dikenal: $type"
      ;;
  esac
}

deploy_materialize_raw_locations() {
  local spec=""
  for spec in "${DEPLOY_LOCATION_RAW_SPECS[@]-}"; do
    deploy_materialize_location_cli "$spec"
  done
}

deploy_choose_ssl_mode() {
  if [[ -n "$DEPLOY_SSL_MODE" ]]; then
    return
  fi

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    printf '\nMode SSL:\n'
    printf '  - none                 Deploy HTTP saja.\n'
    printf '  - certbot-nginx        Certbot nginx plugin untuk issue/manage sertifikat.\n'
    printf '  - existing-certificate Pakai path sertifikat yang sudah ada.\n'
    DEPLOY_SSL_MODE="$(ui_select "Pilih mode SSL" "none" none certbot-nginx existing-certificate)"
  else
    DEPLOY_SSL_MODE="none"
  fi
}

deploy_prompt_domain_settings() {
  if [[ -z "$DEPLOY_MAIN_DOMAIN" ]]; then
    if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
      DEPLOY_MAIN_DOMAIN="$(ui_input "Domain utama" "")"
    else
      die "Domain wajib diisi. Gunakan --domain <domain>."
    fi
  fi

  validate_domain_name "$DEPLOY_MAIN_DOMAIN" || die "Domain tidak valid: $DEPLOY_MAIN_DOMAIN"

  if [[ -z "$DEPLOY_WWW_MODE" ]] && (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    DEPLOY_WWW_MODE="$(ui_select "Aktifkan alias www?" "no" yes no)"
  fi
  DEPLOY_WWW_MODE="$(deploy_default_bool "$DEPLOY_WWW_MODE" "no")"

  if [[ -z "$DEPLOY_ADDITIONAL_ALIASES" ]] && (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    DEPLOY_ADDITIONAL_ALIASES="$(ui_input_optional_csv "Alias domain tambahan (pisahkan koma, kosong = tidak ada)" "")"
  fi

  if [[ -z "$DEPLOY_CANONICAL" ]] && (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    DEPLOY_CANONICAL="$(ui_select "Canonical host" "none" none apex www custom)"
  fi
  DEPLOY_CANONICAL="$(deploy_default_bool "$DEPLOY_CANONICAL" "none")"

  if [[ "$DEPLOY_CANONICAL" == "custom" && -z "$DEPLOY_CANONICAL_HOST" ]]; then
    if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
      DEPLOY_CANONICAL_HOST="$(ui_input "Custom primary domain" "$DEPLOY_MAIN_DOMAIN")"
    else
      die "Canonical custom butuh --canonical-host <domain>."
    fi
  fi

  deploy_finalize_domains
}

deploy_collect_single_app() {
  if [[ -z "$DEPLOY_APP_NAME" ]]; then
    DEPLOY_APP_NAME="$(deploy_select_app_pm2 "Pilih app untuk route /" "")"
  fi

  local app_row=""
  app_row="$(deploy_resolve_app_record "$DEPLOY_APP_NAME")"
  local app_type
  IFS=$'\t' read -r DEPLOY_PRIMARY_PROJECT_DIR app_type DEPLOY_PRIMARY_PM2_NAME DEPLOY_PRIMARY_PORT <<< "$app_row"

  if [[ -n "$DEPLOY_APP_PORT_OVERRIDE" ]]; then
    validate_port "$DEPLOY_APP_PORT_OVERRIDE" || die "Port override tidak valid: $DEPLOY_APP_PORT_OVERRIDE"
    DEPLOY_PRIMARY_PORT="$DEPLOY_APP_PORT_OVERRIDE"
  fi

  deploy_add_location_spec "proxy|/|app|$DEPLOY_PRIMARY_PROJECT_DIR|$DEPLOY_PRIMARY_PM2_NAME|$DEPLOY_UPSTREAM_HOST|$DEPLOY_PRIMARY_PORT"
  deploy_add_route_summary "/ -> $DEPLOY_PRIMARY_PM2_NAME ($DEPLOY_UPSTREAM_HOST:$DEPLOY_PRIMARY_PORT)"
}

deploy_collect_frontend_backend() {
  if [[ -z "$DEPLOY_FRONTEND_APP" ]]; then
    DEPLOY_FRONTEND_APP="$(deploy_select_app_pm2 "Pilih app frontend untuk /" "$DEPLOY_APP_NAME")"
  fi
  if [[ -z "$DEPLOY_BACKEND_APP" ]]; then
    DEPLOY_BACKEND_APP="$(deploy_select_app_pm2 "Pilih app backend untuk /api/" "")"
  fi

  local front_row back_row front_type back_type
  front_row="$(deploy_resolve_app_record "$DEPLOY_FRONTEND_APP")"
  back_row="$(deploy_resolve_app_record "$DEPLOY_BACKEND_APP")"
  IFS=$'\t' read -r DEPLOY_PRIMARY_PROJECT_DIR front_type DEPLOY_PRIMARY_PM2_NAME DEPLOY_PRIMARY_PORT <<< "$front_row"
  local backend_project backend_pm2 backend_port
  IFS=$'\t' read -r backend_project back_type backend_pm2 backend_port <<< "$back_row"

  deploy_add_location_spec "proxy|/|app|$DEPLOY_PRIMARY_PROJECT_DIR|$DEPLOY_PRIMARY_PM2_NAME|$DEPLOY_UPSTREAM_HOST|$DEPLOY_PRIMARY_PORT"
  deploy_add_location_spec "proxy|/api/|app|$backend_project|$backend_pm2|$DEPLOY_UPSTREAM_HOST|$backend_port"
  deploy_add_route_summary "/ -> $DEPLOY_PRIMARY_PM2_NAME ($DEPLOY_UPSTREAM_HOST:$DEPLOY_PRIMARY_PORT)"
  deploy_add_route_summary "/api/ -> $backend_pm2 ($DEPLOY_UPSTREAM_HOST:$backend_port)"

  if [[ -z "$DEPLOY_UPLOADS_PATH" ]] && (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    if ui_confirm "Tambah alias /uploads/ ?" "no"; then
      DEPLOY_UPLOADS_PATH="$(ui_input "Path alias /uploads/" "")"
    fi
  fi

  if [[ -n "$DEPLOY_UPLOADS_PATH" ]]; then
    DEPLOY_UPLOADS_CACHE="$(deploy_default_bool "$DEPLOY_UPLOADS_CACHE" "$DEPLOY_STATIC_CACHE")"
    deploy_add_location_spec "alias|/uploads/|$DEPLOY_UPLOADS_PATH"
    deploy_add_route_summary "/uploads/ -> alias:$DEPLOY_UPLOADS_PATH"
  fi
}

deploy_collect_static_only() {
  if [[ -z "$DEPLOY_STATIC_ROOT" ]]; then
    if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
      DEPLOY_STATIC_ROOT="$(ui_input "Static root directory" "")"
    else
      die "Mode static-only butuh --static-root <path>."
    fi
  fi

  deploy_add_location_spec "root|/|$DEPLOY_STATIC_ROOT"
  deploy_add_route_summary "/ -> root:$DEPLOY_STATIC_ROOT"
}

deploy_collect_redirect_only() {
  if [[ -z "$DEPLOY_REDIRECT_TARGET" ]]; then
    if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
      DEPLOY_REDIRECT_TARGET="$(ui_input "Target redirect" "https://$DEPLOY_PRIMARY_DOMAIN")"
    else
      die "Mode redirect-only butuh --redirect-target <url>."
    fi
  fi

  deploy_add_route_summary "/ -> redirect:$DEPLOY_REDIRECT_TARGET ($DEPLOY_REDIRECT_CODE)"
}

deploy_collect_maintenance() {
  if [[ -z "$DEPLOY_MAINTENANCE_ROOT" ]] && (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    DEPLOY_GENERATE_MAINTENANCE="$(ui_select "Generate halaman maintenance default?" "yes" yes no)"
    if [[ "$DEPLOY_GENERATE_MAINTENANCE" == "no" ]]; then
      DEPLOY_MAINTENANCE_ROOT="$(ui_input "Directory maintenance page" "")"
    fi
  fi

  if [[ -z "$DEPLOY_MAINTENANCE_ROOT" && "$DEPLOY_GENERATE_MAINTENANCE" != "yes" ]]; then
    die "Mode maintenance butuh --maintenance-root <path> atau set generate maintenance."
  fi

  if [[ "$DEPLOY_GENERATE_MAINTENANCE" == "yes" && -z "$DEPLOY_MAINTENANCE_ROOT" ]]; then
    DEPLOY_MAINTENANCE_ROOT="/var/www/gas-maintenance/${DEPLOY_PRIMARY_DOMAIN}"
  fi

  deploy_add_route_summary "/ -> maintenance page"
}

deploy_collect_custom_locations() {
  local needs_prompt=0
  if (( ${#DEPLOY_LOCATION_SPECS[@]} == 0 )); then
    needs_prompt=1
  fi
  if (( needs_prompt == 0 )); then
    return
  fi

  if (( UI_ENABLED == 0 )) || (( ASSUME_YES == 1 )); then
    die "Mode custom-multi-location butuh minimal satu --location."
  fi

  while true; do
    local path
    path="$(ui_input "Path location (contoh /, /api/, /uploads/)" "/")"
    local type
    printf '\nTipe location:\n'
    printf '  - proxy-app      Proxy ke app metadata gas.\n'
    printf '  - proxy-manual   Proxy ke host:port manual.\n'
    printf '  - alias          Alias ke directory static.\n'
    printf '  - root           Root static.\n'
    printf '  - redirect       Redirect ke URL lain.\n'
    printf '  - return         Return custom response sederhana.\n'
    type="$(ui_select "Pilih tipe location" "proxy-app" proxy-app proxy-manual alias root redirect return)"

    case "$type" in
      proxy-app)
        local app_name
        app_name="$(deploy_select_app_pm2 "Pilih app untuk $path" "")"
        local row app_type project_dir port
        row="$(deploy_resolve_app_record "$app_name")"
        IFS=$'\t' read -r project_dir app_type app_name port <<< "$row"
        deploy_add_location_spec "proxy|$path|app|$project_dir|$app_name|$DEPLOY_UPSTREAM_HOST|$port"
        deploy_add_route_summary "$path -> $app_name ($DEPLOY_UPSTREAM_HOST:$port)"
        if [[ -z "$DEPLOY_PRIMARY_PM2_NAME" ]]; then
          DEPLOY_PRIMARY_PROJECT_DIR="$project_dir"
          DEPLOY_PRIMARY_PM2_NAME="$app_name"
          DEPLOY_PRIMARY_PORT="$port"
        fi
        ;;
      proxy-manual)
        local manual_host manual_port
        manual_host="$(ui_input "Upstream host" "$DEPLOY_UPSTREAM_HOST")"
        manual_port="$(ui_input "Upstream port" "")"
        validate_port "$manual_port" || die "Port upstream manual tidak valid: $manual_port"
        deploy_add_location_spec "proxy|$path|manual||manual:$manual_host:$manual_port|$manual_host|$manual_port"
        deploy_add_route_summary "$path -> $manual_host:$manual_port"
        ;;
      alias)
        local alias_path
        alias_path="$(ui_input "Directory alias" "")"
        deploy_add_location_spec "alias|$path|$alias_path"
        deploy_add_route_summary "$path -> alias:$alias_path"
        ;;
      root)
        local root_path
        root_path="$(ui_input "Directory root" "")"
        deploy_add_location_spec "root|$path|$root_path"
        deploy_add_route_summary "$path -> root:$root_path"
        ;;
      redirect)
        local code target
        code="$(ui_input "HTTP redirect code" "301")"
        target="$(ui_input "Target redirect URL" "")"
        deploy_add_location_spec "redirect|$path|$code|$target"
        deploy_add_route_summary "$path -> redirect:$target ($code)"
        ;;
      return)
        local code body
        code="$(ui_input "HTTP return code" "200")"
        body="$(ui_input "Response text" "ok")"
        deploy_add_location_spec "return|$path|$code|$body"
        deploy_add_route_summary "$path -> return $code"
        ;;
    esac

    ui_confirm "Tambah location lain?" "no" || break
  done
}

deploy_collect_mode_routes() {
  DEPLOY_LOCATION_SPECS=()
  DEPLOY_ROUTE_SUMMARY=()

  case "$DEPLOY_MODE" in
    single-app)
      deploy_collect_single_app
      ;;
    frontend-backend-split)
      deploy_collect_frontend_backend
      ;;
    custom-multi-location)
      if [[ "${DEPLOY_LOCATION_RAW_SPECS+set}" == "set" ]] && (( ${#DEPLOY_LOCATION_RAW_SPECS[@]} > 0 )); then
        deploy_materialize_raw_locations
      fi
      deploy_collect_custom_locations
      ;;
    static-only)
      deploy_collect_static_only
      ;;
    redirect-only)
      deploy_collect_redirect_only
      ;;
    maintenance)
      deploy_collect_maintenance
      ;;
    *)
      die "Mode deploy tidak dikenali: $DEPLOY_MODE"
      ;;
  esac

  if [[ "$DEPLOY_MODE" != "custom-multi-location" && "${DEPLOY_LOCATION_RAW_SPECS+set}" == "set" ]] && (( ${#DEPLOY_LOCATION_RAW_SPECS[@]} > 0 )); then
    deploy_materialize_raw_locations
  fi
}

deploy_prompt_advanced_options() {
  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    printf '\nOpsi global deploy:\n'
    DEPLOY_PREVIEW_BEFORE_WRITE="$(deploy_default_bool "$DEPLOY_PREVIEW_BEFORE_WRITE" "yes")"
    if [[ -z "$DEPLOY_SSL_MODE" || "$DEPLOY_SSL_MODE" == "none" ]]; then
      :
    fi

    if [[ -z "$DEPLOY_CLIENT_MAX_BODY_SIZE" ]]; then
      local set_body=""
      set_body="$(ui_select "Set client_max_body_size?" "no" yes no)"
      if [[ "$set_body" == "yes" ]]; then
        DEPLOY_CLIENT_MAX_BODY_SIZE="$(ui_input "client_max_body_size" "10m")"
      fi
    fi

    if [[ -z "$DEPLOY_PROXY_TIMEOUT" ]] && deploy_should_use_proxy_defaults; then
      local set_timeout=""
      set_timeout="$(ui_select "Set proxy timeout?" "no" yes no)"
      if [[ "$set_timeout" == "yes" ]]; then
        DEPLOY_PROXY_TIMEOUT="$(ui_input "Proxy timeout (detik)" "60")"
      fi
    fi

    if [[ -z "$DEPLOY_GZIP_MODE" ]]; then
      DEPLOY_GZIP_MODE="on"
    fi
    DEPLOY_GZIP_MODE="$(ui_select "Gzip preset" "$DEPLOY_GZIP_MODE" on off)"
    DEPLOY_SECURITY_HEADERS="$(ui_select "Security headers preset" "$DEPLOY_SECURITY_HEADERS" basic strict off)"
    DEPLOY_ACCESS_LOG="$(ui_select "Access log" "$DEPLOY_ACCESS_LOG" yes no)"
    DEPLOY_BACKUP="$(ui_select "Backup config existing sebelum overwrite?" "$DEPLOY_BACKUP" yes no)"
    DEPLOY_KEEP_ROLLBACK="$(ui_select "Keep old config rollback point?" "$DEPLOY_KEEP_ROLLBACK" yes no)"
    DEPLOY_TEST_CONFIG="$(ui_select "Test config dengan nginx -t sebelum reload?" "$DEPLOY_TEST_CONFIG" yes no)"
    DEPLOY_RELOAD="$(ui_select "Reload nginx otomatis jika valid?" "$DEPLOY_RELOAD" yes no)"
    DEPLOY_VERIFY="$(ui_select "Jalankan verifikasi lokal/domain setelah deploy?" "$DEPLOY_VERIFY" yes no)"
    DEPLOY_DISABLE_DEFAULT_SITE="$(ui_select "Disable default nginx site?" "$DEPLOY_DISABLE_DEFAULT_SITE" yes no)"
    DEPLOY_CATCHALL="$(ui_select "Create/update catchall 444?" "$DEPLOY_CATCHALL" yes no)"
    if [[ "$DEPLOY_CATCHALL" == "yes" ]]; then
      DEPLOY_CATCHALL_HTTPS="$(ui_select "Catchall 444 juga untuk 443?" "$DEPLOY_CATCHALL_HTTPS" yes no)"
    fi
  fi

  if [[ "$DEPLOY_SSL_MODE" == "existing-certificate" ]]; then
    if [[ -z "$DEPLOY_SSL_CERT" ]]; then
      if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
        DEPLOY_SSL_CERT="$(ui_input "ssl_certificate path" "")"
      else
        die "SSL existing-certificate butuh --ssl-cert <path>."
      fi
    fi
    if [[ -z "$DEPLOY_SSL_KEY" ]]; then
      if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
        DEPLOY_SSL_KEY="$(ui_input "ssl_certificate_key path" "")"
      else
        die "SSL existing-certificate butuh --ssl-key <path>."
      fi
    fi
  fi
}

deploy_collect_wizard() {
  local db_path="$1"
  init_ui_mode
  deploy_load_apps "$db_path"

  if [[ -z "$DEPLOY_APP_NAME" && -z "$DEPLOY_FRONTEND_APP" && -z "$DEPLOY_BACKEND_APP" ]]; then
    if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
      DEPLOY_APP_NAME="$(deploy_select_app_pm2 "Pilih app / source config default" "")"
    fi
  fi

  deploy_pick_server_type
  [[ "$DEPLOY_SERVER_TYPE" == "nginx" ]] || die "Deploy server '$DEPLOY_SERVER_TYPE' belum didukung. Gunakan nginx."

  deploy_prompt_domain_settings
  deploy_pick_default_mode
  deploy_choose_ssl_mode
  deploy_ensure_global_defaults
  deploy_collect_mode_routes
  deploy_prompt_advanced_options
}

deploy_find_primary_from_locations() {
  if [[ -n "$DEPLOY_PRIMARY_PM2_NAME" ]]; then
    return
  fi

  local spec=""
  for spec in "${DEPLOY_LOCATION_SPECS[@]-}"; do
    IFS='|' read -r type path kind project_dir pm2_name host port extra <<< "$spec"
    if [[ "$type" == "proxy" && "$kind" == "app" ]]; then
      DEPLOY_PRIMARY_PROJECT_DIR="$project_dir"
      DEPLOY_PRIMARY_PM2_NAME="$pm2_name"
      DEPLOY_PRIMARY_PORT="$port"
      return
    fi
  done
}

deploy_proxy_directives() {
  local host="$1"
  local port="$2"
  local config=""
  deploy_line config "        proxy_http_version 1.1;"
  deploy_line config "        proxy_set_header Host \$host;"
  deploy_line config "        proxy_set_header X-Real-IP \$remote_addr;"
  deploy_line config "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
  deploy_line config "        proxy_set_header X-Forwarded-Proto \$scheme;"
  if [[ "$DEPLOY_WEBSOCKET" == "yes" ]]; then
    deploy_line config "        proxy_set_header Upgrade \$http_upgrade;"
    deploy_line config "        proxy_set_header Connection \"upgrade\";"
  fi
  if [[ -n "$DEPLOY_PROXY_TIMEOUT" ]]; then
    deploy_line config "        proxy_connect_timeout ${DEPLOY_PROXY_TIMEOUT}s;"
    deploy_line config "        proxy_send_timeout ${DEPLOY_PROXY_TIMEOUT}s;"
    deploy_line config "        proxy_read_timeout ${DEPLOY_PROXY_TIMEOUT}s;"
  fi
  deploy_line config "        proxy_pass http://${host}:${port};"
  printf '%s' "$config"
}

deploy_static_cache_directives() {
  local preset="$1"
  local block=""
  case "$preset" in
    aggressive)
      deploy_line block "        expires 30d;"
      deploy_line block "        add_header Cache-Control \"public, immutable\";"
      ;;
    basic|"")
      deploy_line block "        expires 1h;"
      deploy_line block "        add_header Cache-Control \"public, max-age=3600\";"
      ;;
    off)
      ;;
  esac
  printf '%s' "$block"
}

deploy_render_location_block() {
  local spec="$1"
  local block=""
  local type path field3 field4 field5 field6 field7
  local rendered_block=""
  IFS='|' read -r type path field3 field4 field5 field6 field7 <<< "$spec"

  case "$type" in
    proxy)
      deploy_line block "    location $path {"
      rendered_block="$(deploy_proxy_directives "$field6" "$field7")"
      [[ -n "$rendered_block" ]] && block+="${rendered_block}"$'\n'
      deploy_line block "    }"
      ;;
    alias)
      deploy_line block "    location $path {"
      deploy_line block "        alias $field3;"
      rendered_block="$(deploy_static_cache_directives "$DEPLOY_STATIC_CACHE")"
      [[ -n "$rendered_block" ]] && block+="${rendered_block}"$'\n'
      if [[ "$DEPLOY_ACCESS_LOG" == "no" ]]; then
        deploy_line block "        access_log off;"
      fi
      deploy_line block "        try_files \$uri \$uri/ =404;"
      deploy_line block "    }"
      ;;
    root)
      if [[ "$path" == "/" ]]; then
        deploy_line block "    root $field3;"
        deploy_line block "    index index.html;"
        deploy_line block "    location / {"
        deploy_line block "        try_files \$uri \$uri/ /index.html;"
        rendered_block="$(deploy_static_cache_directives "$DEPLOY_STATIC_CACHE")"
        [[ -n "$rendered_block" ]] && block+="${rendered_block}"$'\n'
        deploy_line block "    }"
      else
        deploy_line block "    location $path {"
        deploy_line block "        root $field3;"
        rendered_block="$(deploy_static_cache_directives "$DEPLOY_STATIC_CACHE")"
        [[ -n "$rendered_block" ]] && block+="${rendered_block}"$'\n'
        deploy_line block "        try_files \$uri \$uri/ =404;"
        deploy_line block "    }"
      fi
      ;;
    redirect)
      deploy_line block "    location $path {"
      deploy_line block "        return $field3 $field4;"
      deploy_line block "    }"
      ;;
    return)
      deploy_line block "    location $path {"
      deploy_line block "        default_type text/plain;"
      deploy_line block "        return $field3 \"$field4\";"
      deploy_line block "    }"
      ;;
  esac

  printf '%s' "$block"
}

deploy_render_shared_server_directives() {
  local block=""
  deploy_line block "    server_name $(deploy_server_name_line);"
  if [[ "$DEPLOY_ACCESS_LOG" == "no" ]]; then
    deploy_line block "    access_log off;"
  fi
  if [[ -n "$DEPLOY_ERROR_LOG_PATH" ]]; then
    deploy_line block "    error_log $DEPLOY_ERROR_LOG_PATH;"
  fi
  if [[ -n "$DEPLOY_CLIENT_MAX_BODY_SIZE" ]]; then
    deploy_line block "    client_max_body_size $DEPLOY_CLIENT_MAX_BODY_SIZE;"
  fi
  if [[ "$DEPLOY_GZIP_MODE" == "on" ]]; then
    deploy_line block "    gzip on;"
    deploy_line block "    gzip_types text/plain text/css application/json application/javascript application/xml+rss image/svg+xml;"
  fi

  case "$DEPLOY_SECURITY_HEADERS" in
    basic)
      deploy_line block "    add_header X-Frame-Options \"SAMEORIGIN\" always;"
      deploy_line block "    add_header X-Content-Type-Options \"nosniff\" always;"
      deploy_line block "    add_header Referrer-Policy \"strict-origin-when-cross-origin\" always;"
      deploy_line block "    add_header Permissions-Policy \"camera=(), microphone=(), geolocation=()\" always;"
      ;;
    strict)
      deploy_line block "    add_header X-Frame-Options \"DENY\" always;"
      deploy_line block "    add_header X-Content-Type-Options \"nosniff\" always;"
      deploy_line block "    add_header Referrer-Policy \"no-referrer\" always;"
      deploy_line block "    add_header Permissions-Policy \"camera=(), microphone=(), geolocation=()\" always;"
      deploy_line block "    add_header Content-Security-Policy \"upgrade-insecure-requests\" always;"
      if [[ "$DEPLOY_SSL_MODE" != "none" ]]; then
        deploy_line block "    add_header Strict-Transport-Security \"max-age=31536000; includeSubDomains\" always;"
      fi
      ;;
  esac

  if [[ -n "$DEPLOY_CUSTOM_ERROR_ROOT" ]]; then
    deploy_line block "    error_page 500 502 503 504 /50x.html;"
    deploy_line block "    location = /50x.html {"
    deploy_line block "        root $DEPLOY_CUSTOM_ERROR_ROOT;"
    deploy_line block "        internal;"
    deploy_line block "    }"
  fi

  if [[ "$DEPLOY_MODE" == "redirect-only" ]]; then
    deploy_line block "    location / {"
    deploy_line block "        return $DEPLOY_REDIRECT_CODE $DEPLOY_REDIRECT_TARGET;"
    deploy_line block "    }"
  elif [[ "$DEPLOY_MODE" == "maintenance" ]]; then
    deploy_line block "    root $DEPLOY_MAINTENANCE_ROOT;"
    deploy_line block "    index index.html;"
    deploy_line block "    location / {"
    deploy_line block "        try_files /index.html =503;"
    deploy_line block "    }"
  else
    local spec=""
    local rendered_block=""
    for spec in "${DEPLOY_LOCATION_SPECS[@]-}"; do
      rendered_block="$(deploy_render_location_block "$spec")"
      [[ -n "$rendered_block" ]] && block+="${rendered_block}"$'\n'
    done
  fi

  printf '%s' "$block"
}

deploy_render_http_server() {
  local block=""
  deploy_line block "server {"
  deploy_line block "    listen 80;"
  deploy_line block "    listen [::]:80;"
  if [[ "$DEPLOY_SSL_MODE" != "none" && "$DEPLOY_FORCE_HTTPS" == "yes" ]]; then
    deploy_line block "    server_name $(deploy_server_name_line);"
    deploy_line block "    if (\$host != $DEPLOY_PRIMARY_DOMAIN) {"
    deploy_line block "        return 301 https://$DEPLOY_PRIMARY_DOMAIN\$request_uri;"
    deploy_line block "    }"
    deploy_line block "    return 301 https://$DEPLOY_PRIMARY_DOMAIN\$request_uri;"
    deploy_line block "}"
    printf '%s' "$block"
    return
  fi

  local shared_block=""
  shared_block="$(deploy_render_shared_server_directives)"
  [[ -n "$shared_block" ]] && block+="${shared_block}"$'\n'
  if [[ "$DEPLOY_CANONICAL" != "none" ]]; then
    deploy_line block "    if (\$host != $DEPLOY_PRIMARY_DOMAIN) {"
      deploy_line block "        return 301 \$scheme://$DEPLOY_PRIMARY_DOMAIN\$request_uri;"
    deploy_line block "    }"
  fi
  deploy_line block "}"
  printf '%s' "$block"
}

deploy_certbot_ssl_live_dir() {
  printf '/etc/letsencrypt/live/%s\n' "$DEPLOY_PRIMARY_DOMAIN"
}

deploy_render_https_server_certbot() {
  local block=""
  local live_dir
  local shared_block=""
  live_dir="$(deploy_certbot_ssl_live_dir)"

  deploy_line block "server {"
  deploy_line block "    listen 443 ssl$( [[ "$DEPLOY_HTTP2" == "yes" ]] && printf ' http2' );"
  deploy_line block "    listen [::]:443 ssl$( [[ "$DEPLOY_HTTP2" == "yes" ]] && printf ' http2' );"
  deploy_line block "    ssl_certificate ${live_dir}/fullchain.pem;"
  deploy_line block "    ssl_certificate_key ${live_dir}/privkey.pem;"
  deploy_line block "    include /etc/letsencrypt/options-ssl-nginx.conf;"
  deploy_line block "    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;"
  shared_block="$(deploy_render_shared_server_directives)"
  [[ -n "$shared_block" ]] && block+="${shared_block}"$'\n'
  deploy_line block "}"
  printf '%s' "$block"
}

deploy_render_https_server_existing_cert() {
  local block=""
  local shared_block=""
  deploy_line block "server {"
  deploy_line block "    listen 443 ssl$( [[ "$DEPLOY_HTTP2" == "yes" ]] && printf ' http2' );"
  deploy_line block "    listen [::]:443 ssl$( [[ "$DEPLOY_HTTP2" == "yes" ]] && printf ' http2' );"
  deploy_line block "    ssl_certificate $DEPLOY_SSL_CERT;"
  deploy_line block "    ssl_certificate_key $DEPLOY_SSL_KEY;"
  if [[ -n "$DEPLOY_SSL_PARAMS" ]]; then
    deploy_line block "    include $DEPLOY_SSL_PARAMS;"
  fi
  shared_block="$(deploy_render_shared_server_directives)"
  [[ -n "$shared_block" ]] && block+="${shared_block}"$'\n'
  deploy_line block "}"
  printf '%s' "$block"
}

deploy_render_config() {
  deploy_find_primary_from_locations

  local generated_at
  generated_at="$(date +"%Y-%m-%d %H:%M:%S %Z")"
  local ports_summary="-"
  if [[ -n "$DEPLOY_PRIMARY_PORT" ]]; then
    ports_summary="$DEPLOY_PRIMARY_PORT"
  fi

  local config=""
  deploy_line config "# managed by gas"
  deploy_line config "# generated at: $generated_at"
  deploy_line config "# app name(s): ${DEPLOY_PRIMARY_PM2_NAME:--}"
  deploy_line config "# port(s): $ports_summary"
  deploy_line config "# deploy mode: $DEPLOY_MODE"
  deploy_line config "# ssl mode: $DEPLOY_SSL_MODE"
  deploy_line config ""
  config+=$(deploy_render_http_server)
  if [[ "$DEPLOY_SSL_MODE" == "existing-certificate" ]]; then
    deploy_line config ""
    config+=$(deploy_render_https_server_existing_cert)
  elif [[ "$DEPLOY_SSL_MODE" == "certbot-nginx" ]]; then
    deploy_line config ""
    config+=$(deploy_render_https_server_certbot)
  fi
  printf '%s' "$config"
}

deploy_render_certbot_bootstrap_config() {
  local saved_ssl_mode="$DEPLOY_SSL_MODE"
  local saved_force_https="$DEPLOY_FORCE_HTTPS"
  local config=""

  DEPLOY_SSL_MODE="none"
  DEPLOY_FORCE_HTTPS="no"
  config="$(deploy_render_config)"

  DEPLOY_SSL_MODE="$saved_ssl_mode"
  DEPLOY_FORCE_HTTPS="$saved_force_https"
  printf '%s' "$config"
}

deploy_primary_nginx_path() {
  nginx_site_available_path "$DEPLOY_PRIMARY_DOMAIN"
}

deploy_deployment_exists() {
  local domain="$1"
  local db_path="$2"
  local row=""
  row="$(query_deployment_row "$db_path" "$domain" 2>/dev/null || true)"
  [[ -n "$row" ]]
}

deploy_write_preview_file() {
  local config_text="$1"
  local output_path="$DEPLOY_SAVE_PREVIEW_PATH"

  if [[ -z "$output_path" || "$output_path" == "temp" ]]; then
    output_path="$(mktemp "/tmp/gas-deploy-${DEPLOY_PRIMARY_DOMAIN}.XXXXXX.conf")"
  fi

  printf '%s\n' "$config_text" > "$output_path"
  printf '%s\n' "$output_path"
}

deploy_show_preview() {
  local config_text="$1"
  printf '\n===== nginx preview: %s =====\n' "$DEPLOY_PRIMARY_DOMAIN"
  printf '%s\n' "$config_text"
  printf '===== end preview =====\n'

  if [[ -n "$DEPLOY_SAVE_PREVIEW_PATH" ]]; then
    local preview_path=""
    preview_path="$(deploy_write_preview_file "$config_text")"
    printf 'Preview tersimpan di: %s\n' "$preview_path"
  fi
}

deploy_collect_app_map() {
  local app_map=""
  local spec=""
  for spec in "${DEPLOY_ROUTE_SUMMARY[@]-}"; do
    if [[ -n "$app_map" ]]; then
      app_map+="; "
    fi
    app_map+="$spec"
  done
  printf '%s\n' "$app_map"
}

deploy_confirm_overwrite() {
  local domain="$1"
  if [[ "$DEPLOY_REUSE_EXISTING" == "yes" ]]; then
    return 0
  fi
  if [[ "$DEPLOY_REUSE_EXISTING" == "no" ]]; then
    die "Config nginx untuk '$domain' sudah ada. Gunakan --reuse-existing yes untuk update."
  fi

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    ui_confirm "Config untuk '$domain' sudah ada. Overwrite?" "no"
    return
  fi

  die "Config nginx untuk '$domain' sudah ada. Tambahkan --reuse-existing yes atau jalankan mode interaktif."
}

deploy_warn_certbot_requirements() {
  if [[ "$DEPLOY_SSL_MODE" != "certbot-nginx" ]]; then
    return
  fi

  local domain=""
  for domain in $(deploy_all_domains); do
    if command_exists getent; then
      local resolved=""
      resolved="$(getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | sort -u | paste -sd ',' - || true)"
      if [[ -z "$resolved" ]]; then
        log_warn "Domain '$domain' belum resolve dari server ini. Certbot kemungkinan gagal."
      fi
    fi
  done
}

deploy_setup_generated_maintenance() {
  if [[ "$DEPLOY_GENERATE_MAINTENANCE" != "yes" ]]; then
    return
  fi

  DEPLOY_MAINTENANCE_ROOT="/var/www/gas-maintenance/${DEPLOY_PRIMARY_DOMAIN}"
  local q_root q_index
  q_root="$(to_shell_quoted "$DEPLOY_MAINTENANCE_ROOT")"
  q_index="$(to_shell_quoted "$DEPLOY_MAINTENANCE_ROOT/index.html")"
  run_privileged_shell "mkdir -p $q_root"
  local tmp_file
  tmp_file="$(mktemp)"
  printf '%s\n' "<!doctype html><html><head><meta charset=\"utf-8\"><title>Maintenance</title><style>body{font-family:sans-serif;background:#f7f3ea;color:#222;display:grid;place-items:center;min-height:100vh;margin:0}main{max-width:40rem;padding:2rem;text-align:center}h1{font-size:2rem;margin-bottom:.5rem}</style></head><body><main><h1>Maintenance</h1><p>${DEPLOY_PRIMARY_DOMAIN} sedang maintenance. Coba lagi beberapa saat.</p></main></body></html>" > "$tmp_file"
  run_privileged_shell "install -m 644 $(to_shell_quoted "$tmp_file") $q_index"
  rm -f "$tmp_file"
}

deploy_print_summary() {
  printf '\nDeploy Summary\n\n'
  print_kv_line "Domain" "$DEPLOY_PRIMARY_DOMAIN"
  print_kv_line "Aliases" "$(deploy_array_to_csv "${DEPLOY_ALIAS_DOMAINS[@]-}")"
  print_kv_line "Server" "$DEPLOY_SERVER_TYPE"
  print_kv_line "Mode" "$DEPLOY_MODE"
  print_kv_line "SSL" "$DEPLOY_SSL_MODE"
  print_kv_line "Canonical" "$DEPLOY_CANONICAL"
  print_kv_line "Config path" "$(deploy_primary_nginx_path)"
  print_kv_line "Backup" "$DEPLOY_BACKUP"
  print_kv_line "Reload" "$DEPLOY_RELOAD"
  print_kv_line "Catchall" "$DEPLOY_CATCHALL"
  print_kv_line "Routes" "$(deploy_collect_app_map)"
  if [[ -n "$DEPLOY_PRIMARY_PM2_NAME" ]]; then
    print_kv_line "PM2 name" "$DEPLOY_PRIMARY_PM2_NAME"
    print_kv_line "Port" "$DEPLOY_PRIMARY_PORT"
  fi
}

deploy_write_primary_nginx_config() {
  local config_text="$1"
  local conf_path=""

  conf_path="$(write_nginx_config_content "$DEPLOY_PRIMARY_DOMAIN" "$config_text")"
  printf '[gas] Generated nginx config:\n%s\n' "$conf_path" >&2
  enable_nginx_site "$DEPLOY_PRIMARY_DOMAIN"
  printf '%s\n' "$conf_path"
}

deploy_test_written_config() {
  local conf_path="$1"
  if ! nginx_test_config; then
    log_error "nginx -t gagal. Config baru tidak direload."
    print_kv_line "Config file" "$conf_path"
    return 1
  fi
  return 0
}

deploy_maybe_test_and_reload() {
  local conf_path="$1"
  local should_test="no"

  if [[ "$DEPLOY_TEST_CONFIG" == "yes" || "$DEPLOY_RELOAD" == "yes" ]]; then
    should_test="yes"
  fi

  if [[ "$should_test" == "yes" ]]; then
    deploy_test_written_config "$conf_path" || return 1
  fi

  if [[ "$DEPLOY_RELOAD" == "yes" ]]; then
    nginx_reload_service
  fi

  return 0
}

deploy_apply() {
  local db_path="$1"
  local config_text="$2"
  local conf_path
  conf_path="$(deploy_primary_nginx_path)"

  if [[ "$DEPLOY_PREVIEW_BEFORE_WRITE" == "yes" || "$DEPLOY_DRY_RUN" -eq 1 || "$DEPLOY_PREVIEW_ONLY" -eq 1 ]]; then
    deploy_show_preview "$config_text"
  fi

  if (( DEPLOY_DRY_RUN == 1 || DEPLOY_PREVIEW_ONLY == 1 )); then
    printf "Dry-run selesai. Tidak ada file nginx yang ditulis.\n"
    return 0
  fi

  ensure_nginx_installed
  [[ "$DEPLOY_SERVER_TYPE" == "nginx" ]] || die "Saat ini hanya nginx yang didukung."

  if nginx_site_exists "$DEPLOY_PRIMARY_DOMAIN"; then
    deploy_confirm_overwrite "$DEPLOY_PRIMARY_DOMAIN"
  fi

  deploy_setup_generated_maintenance

  local backup_path=""
  if [[ "$DEPLOY_BACKUP" == "yes" ]] && nginx_site_exists "$DEPLOY_PRIMARY_DOMAIN"; then
    backup_path="$(nginx_backup_site "$DEPLOY_PRIMARY_DOMAIN" || true)"
  fi

  if [[ "$DEPLOY_DISABLE_DEFAULT_SITE" == "yes" ]]; then
    disable_nginx_default_site || true
  fi

  if [[ "$DEPLOY_CATCHALL" == "yes" ]]; then
    write_nginx_catchall_444 "$DEPLOY_CATCHALL_HTTPS"
  fi

  if [[ "$DEPLOY_SSL_MODE" == "certbot-nginx" ]]; then
    local bootstrap_config=""
    bootstrap_config="$(deploy_render_certbot_bootstrap_config)"
    conf_path="$(deploy_write_primary_nginx_config "$bootstrap_config")"

    if ! deploy_maybe_test_and_reload "$conf_path"; then
      if [[ -n "$backup_path" ]]; then
        print_kv_line "Backup" "$backup_path"
      fi
      return 1
    fi

    deploy_warn_certbot_requirements
    local -a domains=()
    while IFS= read -r domain; do
      [[ -n "$domain" ]] && domains+=("$domain")
    done < <(deploy_all_domains)
    if ! install_domain_ssl_certbot "${domains[@]}"; then
      log_warn "Certbot gagal. Config HTTP tetap ada, tapi SSL belum aktif."
    else
      conf_path="$(deploy_write_primary_nginx_config "$config_text")"
      if ! deploy_maybe_test_and_reload "$conf_path"; then
        if [[ -n "$backup_path" ]]; then
          print_kv_line "Backup" "$backup_path"
        fi
        return 1
      fi
    fi
  else
    conf_path="$(deploy_write_primary_nginx_config "$config_text")"
    if ! deploy_maybe_test_and_reload "$conf_path"; then
      if [[ -n "$backup_path" ]]; then
        print_kv_line "Backup" "$backup_path"
      fi
      return 1
    fi
  fi

  local alias_csv
  alias_csv="$(deploy_array_to_csv "${DEPLOY_ALIAS_DOMAINS[@]-}")"
  local app_map
  app_map="$(deploy_collect_app_map)"
  upsert_deployment_metadata \
    "$db_path" \
    "$DEPLOY_PRIMARY_DOMAIN" \
    "$DEPLOY_PRIMARY_PROJECT_DIR" \
    "$DEPLOY_PRIMARY_PM2_NAME" \
    "$DEPLOY_PRIMARY_PORT" \
    "$DEPLOY_SERVER_TYPE" \
    "$DEPLOY_MODE" \
    "$DEPLOY_SSL_MODE" \
    "$DEPLOY_PRIMARY_DOMAIN" \
    "$alias_csv" \
    "$app_map" \
    "$conf_path" \
    "1" \
    "$DEPLOY_NOTES"

  upsert_domain_metadata \
    "$db_path" \
    "$DEPLOY_PRIMARY_DOMAIN" \
    "$DEPLOY_PRIMARY_PROJECT_DIR" \
    "$DEPLOY_PRIMARY_PM2_NAME" \
    "$DEPLOY_PRIMARY_PORT" \
    "$conf_path" \
    "$DEPLOY_SSL_MODE"

  if [[ "$DEPLOY_VERIFY" == "yes" ]]; then
    deploy_verify
  fi

  if [[ "$DEPLOY_KEEP_ROLLBACK" != "yes" && -n "$backup_path" ]]; then
    rm -f "$backup_path" 2>/dev/null || true
  fi

  printf "Deploy '%s' selesai.\n" "$DEPLOY_PRIMARY_DOMAIN"
}

deploy_verify_http_url() {
  local label="$1"
  local url="$2"
  if ! command_exists curl; then
    printf '%-16s: skipped (curl tidak tersedia)\n' "$label"
    return 0
  fi
  if curl -kfsS --max-time 5 -I "$url" >/dev/null 2>&1; then
    printf '%-16s: ok %s\n' "$label" "$url"
    return 0
  fi
  printf '%-16s: warn %s\n' "$label" "$url"
  return 1
}

deploy_verify() {
  printf '\nVerification\n\n'
  local has_failure=0

  if [[ "$DEPLOY_VERIFY_UPSTREAM" == "yes" && -n "$DEPLOY_PRIMARY_PORT" ]]; then
    if ! deploy_verify_http_url "Local upstream" "http://${DEPLOY_UPSTREAM_HOST}:${DEPLOY_PRIMARY_PORT}"; then
      has_failure=1
    fi
  fi

  if [[ "$DEPLOY_VERIFY_DOMAIN" == "yes" ]]; then
    if ! deploy_verify_http_url "Domain HTTP" "http://${DEPLOY_PRIMARY_DOMAIN}"; then
      has_failure=1
    fi
    if [[ "$DEPLOY_SSL_MODE" != "none" ]]; then
      if ! deploy_verify_http_url "Domain HTTPS" "https://${DEPLOY_PRIMARY_DOMAIN}"; then
        has_failure=1
      fi
    fi
  fi

  return "$has_failure"
}

deploy_print_list_table_plain() {
  local rows="$1"
  printf '%-28s %-8s %-24s %-18s %-7s %-20s %-28s\n' "Domain" "Server" "Mode" "SSL" "Enabled" "Updated" "Primary App"
  printf '%-28s %-8s %-24s %-18s %-7s %-20s %-28s\n' "----------------------------" "--------" "------------------------" "------------------" "-------" "--------------------" "----------------------------"
  printf '%s\n' "$rows" | awk -F '\t' '
    {
      d=$1; s=$2; m=$3; ssl=$4; en=$5; up=$6; pm2=$7;
      if (d=="") d="-"; if (s=="") s="-"; if (m=="") m="-"; if (ssl=="") ssl="-";
      if (en=="1") en="yes"; else en="no";
      if (up=="") up="-"; if (pm2=="") pm2="-";
      printf "%-28.28s %-8.8s %-24.24s %-18.18s %-7.7s %-20.20s %-28.28s\n", d, s, m, ssl, en, up, pm2;
    }
  '
}

deploy_run_list() {
  local db_path="$1"
  local rows=""
  rows="$(query_deployment_rows "$db_path" 2>/dev/null || true)"
  if [[ -z "$rows" ]]; then
    printf 'Belum ada deployment yang dikelola gas.\n'
    return 0
  fi

  if (( GUM_ENABLED == 1 )); then
    {
      printf 'Domain\tServer\tMode\tSSL\tEnabled\tUpdated\tPrimary App\tPort\tAliases\tPath\n'
      printf '%s\n' "$rows"
    } | gum table
    return 0
  fi

  deploy_print_list_table_plain "$rows"
}

deploy_pick_existing_domain() {
  local db_path="$1"
  local rows=""
  rows="$(query_deployment_rows "$db_path")"
  [[ -n "$rows" ]] || die "Belum ada deployment yang dikelola gas."

  local -a domains=()
  local domain server_type deploy_mode ssl_mode enabled updated_at pm2_name port alias_domains project_dir
  while IFS=$'\t' read -r domain server_type deploy_mode ssl_mode enabled updated_at pm2_name port alias_domains project_dir; do
    [[ -n "$domain" ]] && domains+=("$domain")
  done <<< "$rows"
  (( ${#domains[@]} > 0 )) || die "Belum ada deployment yang dikelola gas."

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    DEPLOY_DOMAIN_REMOVE="$(ui_select "Pilih domain yang mau dihapus" "${domains[0]}" "${domains[@]}")"
    return
  fi

  die "Domain wajib diisi untuk deploy remove. Gunakan --domain <domain>."
}

deploy_run_remove() {
  local db_path="$1"
  if [[ -z "$DEPLOY_DOMAIN_REMOVE" ]]; then
    deploy_pick_existing_domain "$db_path"
  fi

  validate_domain_name "$DEPLOY_DOMAIN_REMOVE" || die "Domain tidak valid: $DEPLOY_DOMAIN_REMOVE"

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    ui_confirm "Hapus deployment nginx untuk '$DEPLOY_DOMAIN_REMOVE'?" "no" || {
      printf 'Aksi deploy remove dibatalkan.\n'
      return 0
    }
  fi

  ensure_nginx_installed
  if [[ "$DEPLOY_REMOVE_ENABLED" == "yes" ]]; then
    disable_nginx_site "$DEPLOY_DOMAIN_REMOVE"
  fi
  if [[ "$DEPLOY_REMOVE_CONFIG" == "yes" ]]; then
    local available_path
    available_path="$(nginx_site_available_path "$DEPLOY_DOMAIN_REMOVE")"
    run_privileged_shell "rm -f $(to_shell_quoted "$available_path")"
  fi
  if [[ "$DEPLOY_REMOVE_TEST" == "yes" ]]; then
    nginx_test_config
  fi
  if [[ "$DEPLOY_REMOVE_RELOAD" == "yes" ]]; then
    nginx_reload_service
  fi

  delete_deployment_metadata "$db_path" "$DEPLOY_DOMAIN_REMOVE"
  delete_domain_metadata "$db_path" "$DEPLOY_DOMAIN_REMOVE"
  printf "Deployment '%s' berhasil dihapus.\n" "$DEPLOY_DOMAIN_REMOVE"
}

deploy_print_doctor_row() {
  local label="$1"
  local status="$2"
  local detail="$3"
  printf '%-24s: %-8s %s\n' "$label" "$status" "$detail"
}

deploy_check_python_certbot_nginx() {
  if ! command_exists python3; then
    printf 'missing\tpython3 tidak tersedia\n'
    return
  fi
  if python3 -c "import certbot_nginx" >/dev/null 2>&1; then
    printf 'ok\tpython module available\n'
  else
    printf 'missing\tmodule certbot_nginx tidak ditemukan\n'
  fi
}

deploy_run_doctor() {
  printf 'Deploy Doctor\n\n'
  local bins=(
    "nginx|nginx|nginx -v 2>&1"
    "certbot|certbot|certbot --version"
    "openssl|openssl|openssl version"
    "pm2|pm2|pm2 -v"
    "sqlite3|sqlite3|sqlite3 --version"
    "gum|gum|gum --version"
    "curl|curl|curl --version | head -n 1"
    "ss/iproute2|ss|ss --version | head -n 1"
    "git|git|git --version"
  )
  local item=""
  for item in "${bins[@]}"; do
    local label="${item%%|*}"
    local rest="${item#*|}"
    local bin_name="${rest%%|*}"
    local version_cmd="${rest#*|}"
    if command_exists "$bin_name"; then
      local version=""
      version="$(bash -lc "$version_cmd" 2>/dev/null || true)"
      version="${version%%$'\n'*}"
      deploy_print_doctor_row "$label" "[ok]" "${version:-installed}"
    else
      deploy_print_doctor_row "$label" "[x]" "not installed"
    fi
  done

  local py_status py_detail
  IFS=$'\t' read -r py_status py_detail <<< "$(deploy_check_python_certbot_nginx)"
  if [[ "$py_status" == "ok" ]]; then
    deploy_print_doctor_row "python3-certbot-nginx" "[ok]" "$py_detail"
  else
    deploy_print_doctor_row "python3-certbot-nginx" "[x]" "$py_detail"
  fi

  if is_root_user || command_exists sudo; then
    deploy_print_doctor_row "privilege" "[ok]" "root/sudo tersedia untuk tulis nginx"
  else
    deploy_print_doctor_row "privilege" "[x]" "butuh root atau sudo"
  fi

  if command_exists ss; then
    local ports80 ports443
    ports80="$(ss -ltn 2>/dev/null | awk '{print $4}' | grep -E '(:|\\.)80$' | head -n 1 || true)"
    ports443="$(ss -ltn 2>/dev/null | awk '{print $4}' | grep -E '(:|\\.)443$' | head -n 1 || true)"
    if [[ -n "$ports80" ]]; then
      deploy_print_doctor_row "port 80" "[ok]" "ada listener lokal"
    else
      deploy_print_doctor_row "port 80" "[warn]" "belum ada listener lokal"
    fi
    if [[ -n "$ports443" ]]; then
      deploy_print_doctor_row "port 443" "[ok]" "ada listener lokal"
    else
      deploy_print_doctor_row "port 443" "[warn]" "belum ada listener lokal"
    fi
  fi
}

parse_deploy_bool_arg() {
  local value=""
  value="$(normalize_yes_no "$1" || true)"
  [[ -n "$value" ]] || die "Nilai harus yes atau no: $1"
  printf '%s\n' "$value"
}

deploy_parse_shared_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        case "$DEPLOY_SUBCOMMAND" in
          list) print_deploy_list_help_plain ;;
          remove) print_deploy_remove_help_plain ;;
          doctor) print_deploy_doctor_help_plain ;;
          preview) print_deploy_preview_help_plain ;;
          *) print_deploy_help_plain ;;
        esac
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
      --server)
        DEPLOY_SERVER_TYPE="$(deploy_lower "$2")"
        shift 2
        ;;
      --server=*)
        DEPLOY_SERVER_TYPE="$(deploy_lower "${1#*=}")"
        shift
        ;;
      --domain)
        DEPLOY_MAIN_DOMAIN="$2"
        shift 2
        ;;
      --domain=*)
        DEPLOY_MAIN_DOMAIN="${1#*=}"
        shift
        ;;
      --app)
        DEPLOY_APP_NAME="$2"
        shift 2
        ;;
      --app=*)
        DEPLOY_APP_NAME="${1#*=}"
        shift
        ;;
      --frontend)
        DEPLOY_FRONTEND_APP="$2"
        shift 2
        ;;
      --frontend=*)
        DEPLOY_FRONTEND_APP="${1#*=}"
        shift
        ;;
      --backend)
        DEPLOY_BACKEND_APP="$2"
        shift 2
        ;;
      --backend=*)
        DEPLOY_BACKEND_APP="${1#*=}"
        shift
        ;;
      --mode)
        DEPLOY_MODE="$(deploy_lower "$2")"
        shift 2
        ;;
      --mode=*)
        DEPLOY_MODE="$(deploy_lower "${1#*=}")"
        shift
        ;;
      --alias-domain)
        if [[ -n "$DEPLOY_ADDITIONAL_ALIASES" ]]; then
          DEPLOY_ADDITIONAL_ALIASES+=","
        fi
        DEPLOY_ADDITIONAL_ALIASES+="$2"
        shift 2
        ;;
      --alias-domain=*)
        if [[ -n "$DEPLOY_ADDITIONAL_ALIASES" ]]; then
          DEPLOY_ADDITIONAL_ALIASES+=","
        fi
        DEPLOY_ADDITIONAL_ALIASES+="${1#*=}"
        shift
        ;;
      --www)
        DEPLOY_WWW_MODE="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --www=*)
        DEPLOY_WWW_MODE="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --canonical)
        DEPLOY_CANONICAL="$(deploy_lower "$2")"
        shift 2
        ;;
      --canonical=*)
        DEPLOY_CANONICAL="$(deploy_lower "${1#*=}")"
        shift
        ;;
      --canonical-host)
        DEPLOY_CANONICAL_HOST="$2"
        shift 2
        ;;
      --canonical-host=*)
        DEPLOY_CANONICAL_HOST="${1#*=}"
        shift
        ;;
      --ssl)
        DEPLOY_SSL_MODE="$(deploy_lower "$2")"
        shift 2
        ;;
      --ssl=*)
        DEPLOY_SSL_MODE="$(deploy_lower "${1#*=}")"
        shift
        ;;
      --ssl-cert)
        DEPLOY_SSL_CERT="$2"
        shift 2
        ;;
      --ssl-cert=*)
        DEPLOY_SSL_CERT="${1#*=}"
        shift
        ;;
      --ssl-key)
        DEPLOY_SSL_KEY="$2"
        shift 2
        ;;
      --ssl-key=*)
        DEPLOY_SSL_KEY="${1#*=}"
        shift
        ;;
      --ssl-params)
        DEPLOY_SSL_PARAMS="$2"
        shift 2
        ;;
      --ssl-params=*)
        DEPLOY_SSL_PARAMS="${1#*=}"
        shift
        ;;
      --http2)
        DEPLOY_HTTP2="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --http2=*)
        DEPLOY_HTTP2="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --force-https)
        DEPLOY_FORCE_HTTPS="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --force-https=*)
        DEPLOY_FORCE_HTTPS="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --websocket)
        DEPLOY_WEBSOCKET="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --websocket=*)
        DEPLOY_WEBSOCKET="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --client-max-body-size)
        DEPLOY_CLIENT_MAX_BODY_SIZE="$2"
        shift 2
        ;;
      --client-max-body-size=*)
        DEPLOY_CLIENT_MAX_BODY_SIZE="${1#*=}"
        shift
        ;;
      --timeout)
        DEPLOY_PROXY_TIMEOUT="$2"
        shift 2
        ;;
      --timeout=*)
        DEPLOY_PROXY_TIMEOUT="${1#*=}"
        shift
        ;;
      --gzip)
        DEPLOY_GZIP_MODE="$(deploy_lower "$2")"
        shift 2
        ;;
      --gzip=*)
        DEPLOY_GZIP_MODE="$(deploy_lower "${1#*=}")"
        shift
        ;;
      --security-headers)
        DEPLOY_SECURITY_HEADERS="$(deploy_lower "$2")"
        shift 2
        ;;
      --security-headers=*)
        DEPLOY_SECURITY_HEADERS="$(deploy_lower "${1#*=}")"
        shift
        ;;
      --static-cache)
        DEPLOY_STATIC_CACHE="$(deploy_lower "$2")"
        shift 2
        ;;
      --static-cache=*)
        DEPLOY_STATIC_CACHE="$(deploy_lower "${1#*=}")"
        shift
        ;;
      --access-log)
        DEPLOY_ACCESS_LOG="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --access-log=*)
        DEPLOY_ACCESS_LOG="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --error-log)
        DEPLOY_ERROR_LOG_PATH="$2"
        shift 2
        ;;
      --error-log=*)
        DEPLOY_ERROR_LOG_PATH="${1#*=}"
        shift
        ;;
      --error-page-root)
        DEPLOY_CUSTOM_ERROR_ROOT="$2"
        shift 2
        ;;
      --error-page-root=*)
        DEPLOY_CUSTOM_ERROR_ROOT="${1#*=}"
        shift
        ;;
      --preview)
        DEPLOY_PREVIEW_BEFORE_WRITE="yes"
        shift
        ;;
      --dry-run)
        DEPLOY_DRY_RUN=1
        DEPLOY_PREVIEW_BEFORE_WRITE="yes"
        shift
        ;;
      --save-preview)
        DEPLOY_SAVE_PREVIEW_PATH="$2"
        shift 2
        ;;
      --save-preview=*)
        DEPLOY_SAVE_PREVIEW_PATH="${1#*=}"
        shift
        ;;
      --backup)
        DEPLOY_BACKUP="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --backup=*)
        DEPLOY_BACKUP="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --test)
        DEPLOY_TEST_CONFIG="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --test=*)
        DEPLOY_TEST_CONFIG="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --reload)
        DEPLOY_RELOAD="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --reload=*)
        DEPLOY_RELOAD="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --verify)
        DEPLOY_VERIFY="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --verify=*)
        DEPLOY_VERIFY="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --verify-upstream)
        DEPLOY_VERIFY_UPSTREAM="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --verify-upstream=*)
        DEPLOY_VERIFY_UPSTREAM="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --verify-domain)
        DEPLOY_VERIFY_DOMAIN="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --verify-domain=*)
        DEPLOY_VERIFY_DOMAIN="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --reuse-existing)
        DEPLOY_REUSE_EXISTING="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --reuse-existing=*)
        DEPLOY_REUSE_EXISTING="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --catchall)
        DEPLOY_CATCHALL="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --catchall=*)
        DEPLOY_CATCHALL="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --catchall-https)
        DEPLOY_CATCHALL_HTTPS="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --catchall-https=*)
        DEPLOY_CATCHALL_HTTPS="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --disable-default-site)
        DEPLOY_DISABLE_DEFAULT_SITE="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --disable-default-site=*)
        DEPLOY_DISABLE_DEFAULT_SITE="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --keep-old-config)
        DEPLOY_KEEP_ROLLBACK="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --keep-old-config=*)
        DEPLOY_KEEP_ROLLBACK="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --upstream-host)
        DEPLOY_UPSTREAM_HOST="$2"
        shift 2
        ;;
      --upstream-host=*)
        DEPLOY_UPSTREAM_HOST="${1#*=}"
        shift
        ;;
      --port)
        DEPLOY_APP_PORT_OVERRIDE="$2"
        shift 2
        ;;
      --port=*)
        DEPLOY_APP_PORT_OVERRIDE="${1#*=}"
        shift
        ;;
      --uploads)
        DEPLOY_UPLOADS_PATH="$2"
        shift 2
        ;;
      --uploads=*)
        DEPLOY_UPLOADS_PATH="${1#*=}"
        shift
        ;;
      --uploads-cache)
        DEPLOY_UPLOADS_CACHE="$(deploy_lower "$2")"
        shift 2
        ;;
      --uploads-cache=*)
        DEPLOY_UPLOADS_CACHE="$(deploy_lower "${1#*=}")"
        shift
        ;;
      --static-root)
        DEPLOY_STATIC_ROOT="$2"
        shift 2
        ;;
      --static-root=*)
        DEPLOY_STATIC_ROOT="${1#*=}"
        shift
        ;;
      --redirect-target)
        DEPLOY_REDIRECT_TARGET="$2"
        shift 2
        ;;
      --redirect-target=*)
        DEPLOY_REDIRECT_TARGET="${1#*=}"
        shift
        ;;
      --redirect-code)
        DEPLOY_REDIRECT_CODE="$2"
        shift 2
        ;;
      --redirect-code=*)
        DEPLOY_REDIRECT_CODE="${1#*=}"
        shift
        ;;
      --maintenance-root)
        DEPLOY_MAINTENANCE_ROOT="$2"
        shift 2
        ;;
      --maintenance-root=*)
        DEPLOY_MAINTENANCE_ROOT="${1#*=}"
        shift
        ;;
      --generate-maintenance)
        DEPLOY_GENERATE_MAINTENANCE="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --generate-maintenance=*)
        DEPLOY_GENERATE_MAINTENANCE="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --location)
        DEPLOY_LOCATION_RAW_SPECS+=("$2")
        shift 2
        ;;
      --location=*)
        DEPLOY_LOCATION_RAW_SPECS+=("${1#*=}")
        shift
        ;;
      --notes)
        DEPLOY_NOTES="$2"
        shift 2
        ;;
      --notes=*)
        DEPLOY_NOTES="${1#*=}"
        shift
        ;;
      --remove-enabled)
        DEPLOY_REMOVE_ENABLED="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --remove-enabled=*)
        DEPLOY_REMOVE_ENABLED="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --remove-config)
        DEPLOY_REMOVE_CONFIG="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --remove-config=*)
        DEPLOY_REMOVE_CONFIG="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --remove-test)
        DEPLOY_REMOVE_TEST="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --remove-test=*)
        DEPLOY_REMOVE_TEST="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --remove-reload)
        DEPLOY_REMOVE_RELOAD="$(parse_deploy_bool_arg "$2")"
        shift 2
        ;;
      --remove-reload=*)
        DEPLOY_REMOVE_RELOAD="$(parse_deploy_bool_arg "${1#*=}")"
        shift
        ;;
      --domain-remove)
        DEPLOY_DOMAIN_REMOVE="$2"
        shift 2
        ;;
      --domain-remove=*)
        DEPLOY_DOMAIN_REMOVE="${1#*=}"
        shift
        ;;
      --*)
        die "Flag deploy tidak dikenali: $1"
        ;;
      *)
        if [[ "$DEPLOY_SUBCOMMAND" == "remove" && -z "$DEPLOY_DOMAIN_REMOVE" ]]; then
          DEPLOY_DOMAIN_REMOVE="$1"
        elif [[ -z "$DEPLOY_MAIN_DOMAIN" ]]; then
          DEPLOY_MAIN_DOMAIN="$1"
        else
          die "Argumen deploy tidak dikenali: $1"
        fi
        shift
        ;;
    esac
  done
}

run_deploy() {
  init_deploy_state

  local first_arg="${1:-}"
  case "$first_arg" in
    add|update)
      DEPLOY_SUBCOMMAND="add"
      shift
      ;;
    list|ls)
      DEPLOY_SUBCOMMAND="list"
      shift
      ;;
    remove|rm|delete)
      DEPLOY_SUBCOMMAND="remove"
      shift
      ;;
    doctor)
      DEPLOY_SUBCOMMAND="doctor"
      shift
      ;;
    preview)
      DEPLOY_SUBCOMMAND="preview"
      DEPLOY_PREVIEW_ONLY=1
      DEPLOY_DRY_RUN=1
      shift
      ;;
    help|--help|-h)
      print_deploy_help_plain
      return 0
      ;;
  esac

  deploy_parse_shared_args "$@"
  init_ui_mode

  local db_path=""
  db_path="$(ensure_metadata_db || true)"
  [[ -n "$db_path" ]] || die "Metadata gas tidak tersedia. Pastikan sqlite3 terpasang."

  case "$DEPLOY_SUBCOMMAND" in
    list)
      deploy_run_list "$db_path"
      ;;
    remove)
      deploy_run_remove "$db_path"
      ;;
    doctor)
      deploy_run_doctor
      ;;
    preview|add)
      deploy_collect_wizard "$db_path"
      deploy_print_summary
      if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )) && [[ "$DEPLOY_SUBCOMMAND" != "preview" ]]; then
        ui_confirm "Apply deploy config sekarang?" "yes" || {
          printf 'Deploy dibatalkan.\n'
          return 0
        }
      fi
      local config_text=""
      config_text="$(deploy_render_config)"
      deploy_apply "$db_path" "$config_text"
      ;;
    *)
      die "Subcommand deploy tidak dikenal: $DEPLOY_SUBCOMMAND"
      ;;
  esac
}
