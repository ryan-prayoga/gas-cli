# shellcheck shell=bash
# SQLite metadata helpers.

sql_literal() {
  local value="$1"
  if [[ -z "$value" ]]; then
    printf 'NULL'
    return
  fi

  local escaped="$value"
  escaped="${escaped//\'/\'\'}"
  printf "'%s'" "$escaped"
}

ensure_metadata_db() {
  if ! command_exists sqlite3; then
    log_warn "sqlite3 tidak ditemukan. Metadata global dilewati."
    return 1
  fi

  local config_dir="$HOME/.config/gas"
  local db_path="$config_dir/apps.db"
  mkdir -p "$config_dir"

  sqlite3 -cmd ".timeout 3000" "$db_path" "
    CREATE TABLE IF NOT EXISTS apps (
      project_dir TEXT PRIMARY KEY,
      app_type TEXT,
      port INTEGER,
      pm2_name TEXT,
      env_file TEXT,
      start_file TEXT,
      run_mode TEXT,
      node_version TEXT,
      npm_version TEXT,
      go_version TEXT,
      svelte_strategy TEXT,
      deps_mode TEXT,
      verify_status TEXT,
      verify_message TEXT,
      updated_at TEXT
    );
    CREATE TABLE IF NOT EXISTS domains (
      domain TEXT PRIMARY KEY,
      project_dir TEXT,
      pm2_name TEXT,
      port INTEGER,
      nginx_conf TEXT,
      ssl_enabled TEXT,
      updated_at TEXT
    );
  "

  local columns=(
    "project_dir|TEXT"
    "app_type|TEXT"
    "port|INTEGER"
    "pm2_name|TEXT"
    "env_file|TEXT"
    "start_file|TEXT"
    "run_mode|TEXT"
    "node_version|TEXT"
    "npm_version|TEXT"
    "go_version|TEXT"
    "svelte_strategy|TEXT"
    "deps_mode|TEXT"
    "verify_status|TEXT"
    "verify_message|TEXT"
    "updated_at|TEXT"
  )

  local item=""
  for item in "${columns[@]}"; do
    local column_name="${item%%|*}"
    local column_type="${item#*|}"
    local exists_count
    exists_count="$(sqlite3 -cmd ".timeout 3000" "$db_path" "SELECT COUNT(*) FROM pragma_table_info('apps') WHERE name='${column_name}';")"
    if [[ "$exists_count" == "0" ]]; then
      sqlite3 -cmd ".timeout 3000" "$db_path" "ALTER TABLE apps ADD COLUMN ${column_name} ${column_type};"
    fi
  done

  local domain_columns=(
    "domain|TEXT"
    "project_dir|TEXT"
    "pm2_name|TEXT"
    "port|INTEGER"
    "nginx_conf|TEXT"
    "ssl_enabled|TEXT"
    "updated_at|TEXT"
  )

  for item in "${domain_columns[@]}"; do
    local column_name="${item%%|*}"
    local column_type="${item#*|}"
    local exists_count
    exists_count="$(sqlite3 -cmd ".timeout 3000" "$db_path" "SELECT COUNT(*) FROM pragma_table_info('domains') WHERE name='${column_name}';")"
    if [[ "$exists_count" == "0" ]]; then
      sqlite3 -cmd ".timeout 3000" "$db_path" "ALTER TABLE domains ADD COLUMN ${column_name} ${column_type};"
    fi
  done

  printf '%s\n' "$db_path"
}

metadata_db_path() {
  printf '%s\n' "$HOME/.config/gas/apps.db"
}

require_sqlite3() {
  if command_exists sqlite3; then
    return 0
  fi
  log_warn "sqlite3 tidak ditemukan. Install sqlite3 untuk pakai command ini."
  return 1
}

db_has_apps_table() {
  local db_path="$1"
  local count
  count="$(sqlite3 -cmd ".timeout 3000" "$db_path" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='apps';" 2>/dev/null || true)"
  [[ "$count" == "1" ]]
}

query_info_row() {
  local db_path="$1"
  local project_dir="$2"
  sqlite3 -cmd ".timeout 3000" -separator $'\t' "$db_path" "
    SELECT
      IFNULL(project_dir, ''),
      IFNULL(app_type, ''),
      IFNULL(pm2_name, ''),
      IFNULL(port, ''),
      IFNULL(svelte_strategy, ''),
      IFNULL(deps_mode, ''),
      IFNULL(updated_at, '')
    FROM apps
    WHERE project_dir = $(sql_literal "$project_dir")
    LIMIT 1;
  "
}

query_build_config_row() {
  local db_path="$1"
  local project_dir="$2"
  sqlite3 -cmd ".timeout 3000" -separator $'\t' "$db_path" "
    SELECT
      IFNULL(app_type, ''),
      IFNULL(pm2_name, ''),
      IFNULL(port, ''),
      IFNULL(svelte_strategy, ''),
      IFNULL(deps_mode, ''),
      IFNULL(run_mode, '')
    FROM apps
    WHERE project_dir = $(sql_literal "$project_dir")
    LIMIT 1;
  "
}

query_list_rows() {
  local db_path="$1"
  sqlite3 -cmd ".timeout 3000" -separator $'\t' "$db_path" "
    SELECT
      IFNULL(pm2_name, ''),
      IFNULL(app_type, ''),
      IFNULL(port, ''),
      IFNULL(updated_at, ''),
      IFNULL(project_dir, '')
    FROM apps
    ORDER BY updated_at DESC;
  "
}

query_apps_candidate_rows() {
  local db_path="$1"
  sqlite3 -cmd ".timeout 3000" -separator $'\t' "$db_path" "
    SELECT
      IFNULL(project_dir, ''),
      IFNULL(app_type, ''),
      IFNULL(pm2_name, ''),
      IFNULL(port, '')
    FROM apps
    ORDER BY updated_at DESC;
  "
}

query_app_by_pm2_name() {
  local db_path="$1"
  local pm2_name="$2"
  sqlite3 -cmd ".timeout 3000" -separator $'\t' "$db_path" "
    SELECT
      IFNULL(project_dir, ''),
      IFNULL(app_type, ''),
      IFNULL(pm2_name, ''),
      IFNULL(port, '')
    FROM apps
    WHERE pm2_name = $(sql_literal "$pm2_name")
    ORDER BY updated_at DESC
    LIMIT 1;
  "
}

query_domain_rows() {
  local db_path="$1"
  sqlite3 -cmd ".timeout 3000" -separator $'\t' "$db_path" "
    SELECT
      IFNULL(domain, ''),
      IFNULL(pm2_name, ''),
      IFNULL(port, ''),
      IFNULL(ssl_enabled, ''),
      IFNULL(updated_at, ''),
      IFNULL(project_dir, '')
    FROM domains
    ORDER BY updated_at DESC;
  "
}

query_domain_row() {
  local db_path="$1"
  local domain="$2"
  sqlite3 -cmd ".timeout 3000" -separator $'\t' "$db_path" "
    SELECT
      IFNULL(domain, ''),
      IFNULL(project_dir, ''),
      IFNULL(pm2_name, ''),
      IFNULL(port, ''),
      IFNULL(nginx_conf, ''),
      IFNULL(ssl_enabled, ''),
      IFNULL(updated_at, '')
    FROM domains
    WHERE domain = $(sql_literal "$domain")
    LIMIT 1;
  "
}

upsert_domain_metadata() {
  local db_path="$1"
  local domain="$2"
  local project_dir="$3"
  local pm2_name="$4"
  local port="$5"
  local nginx_conf="$6"
  local ssl_enabled="$7"

  local now_utc
  now_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local domain_sql project_dir_sql pm2_name_sql port_sql nginx_conf_sql ssl_enabled_sql updated_at_sql
  domain_sql="$(sql_literal "$domain")"
  project_dir_sql="$(sql_literal "$project_dir")"
  pm2_name_sql="$(sql_literal "$pm2_name")"
  port_sql="$(sql_literal "$port")"
  nginx_conf_sql="$(sql_literal "$nginx_conf")"
  ssl_enabled_sql="$(sql_literal "$ssl_enabled")"
  updated_at_sql="$(sql_literal "$now_utc")"

  sqlite3 -cmd ".timeout 3000" "$db_path" "
    BEGIN TRANSACTION;
    DELETE FROM domains WHERE domain = ${domain_sql};
    INSERT INTO domains (
      domain,
      project_dir,
      pm2_name,
      port,
      nginx_conf,
      ssl_enabled,
      updated_at
    ) VALUES (
      ${domain_sql},
      ${project_dir_sql},
      ${pm2_name_sql},
      ${port_sql},
      ${nginx_conf_sql},
      ${ssl_enabled_sql},
      ${updated_at_sql}
    );
    COMMIT;
  "
}

delete_domain_metadata() {
  local db_path="$1"
  local domain="$2"
  sqlite3 -cmd ".timeout 3000" "$db_path" "DELETE FROM domains WHERE domain = $(sql_literal "$domain");"
}

delete_project_metadata() {
  local db_path="$1"
  local project_dir="$2"
  sqlite3 -cmd ".timeout 3000" "$db_path" "DELETE FROM apps WHERE project_dir = $(sql_literal "$project_dir");"
}


write_metadata() {
  local db_path=""
  db_path="$(ensure_metadata_db || true)"
  if [[ -z "$db_path" ]]; then
    return
  fi

  local now_utc
  now_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local project_dir_sql app_type_sql port_sql pm2_name_sql
  local env_file_sql start_file_sql run_mode_sql
  local node_version_sql npm_version_sql go_version_sql
  local svelte_strategy_sql deps_mode_sql verify_status_sql verify_message_sql updated_at_sql

  project_dir_sql="$(sql_literal "$PROJECT_DIR")"
  if [[ "$BUILD_TYPE" == "node-web" && -n "$BUILD_STACK_ID" ]]; then
    app_type_sql="$(sql_literal "$BUILD_STACK_ID")"
  else
    app_type_sql="$(sql_literal "$BUILD_TYPE")"
  fi
  port_sql="$(sql_literal "$BUILD_PORT")"
  pm2_name_sql="$(sql_literal "$BUILD_PM2_NAME")"
  env_file_sql="$(sql_literal "$BUILD_ENV_FILE")"
  start_file_sql="$(sql_literal "$BUILD_START_FILE")"
  run_mode_sql="$(sql_literal "$BUILD_RUN_MODE")"
  node_version_sql="$(sql_literal "$BUILD_NODE_VERSION")"
  npm_version_sql="$(sql_literal "$BUILD_NPM_VERSION")"
  go_version_sql="$(sql_literal "$BUILD_GO_VERSION")"
  svelte_strategy_sql="$(sql_literal "${BUILD_STRATEGY_FINAL:-$BUILD_SVELTE_STRATEGY_FINAL}")"
  deps_mode_sql="$(sql_literal "$BUILD_INSTALL_DEPS")"
  verify_status_sql="$(sql_literal "$BUILD_VERIFY_STATUS")"
  verify_message_sql="$(sql_literal "$BUILD_VERIFY_MESSAGE")"
  updated_at_sql="$(sql_literal "$now_utc")"

  sqlite3 -cmd ".timeout 3000" "$db_path" "
    BEGIN TRANSACTION;
    DELETE FROM apps WHERE project_dir = ${project_dir_sql};
    INSERT INTO apps (
      project_dir,
      app_type,
      port,
      pm2_name,
      env_file,
      start_file,
      run_mode,
      node_version,
      npm_version,
      go_version,
      svelte_strategy,
      deps_mode,
      verify_status,
      verify_message,
      updated_at
    ) VALUES (
      ${project_dir_sql},
      ${app_type_sql},
      ${port_sql},
      ${pm2_name_sql},
      ${env_file_sql},
      ${start_file_sql},
      ${run_mode_sql},
      ${node_version_sql},
      ${npm_version_sql},
      ${go_version_sql},
      ${svelte_strategy_sql},
      ${deps_mode_sql},
      ${verify_status_sql},
      ${verify_message_sql},
      ${updated_at_sql}
    );
    COMMIT;
  "

  log_info "Metadata global disimpan di $db_path"
}
