# shellcheck shell=bash
# PM2 and runtime verification helpers.

pm2_app_exists() {
  local name="$1"
  pm2 describe "$name" >/dev/null 2>&1
}

run_pm2_direct() {
  local script_path="$1"
  local app_name="$2"
  local port="$3"

  if pm2_app_exists "$app_name"; then
    log_info "PM2 app '$app_name' sudah ada. Restart..."
    PORT="$port" pm2 restart "$app_name" --update-env
  else
    log_info "PM2 app '$app_name' belum ada. Start..."
    PORT="$port" pm2 start "$script_path" --name "$app_name" --cwd "$PROJECT_DIR"
  fi
}

pm2_replace_and_start() {
  local command_text="$1"
  local q_name
  q_name="$(to_shell_quoted "$BUILD_PM2_NAME")"
  local replace_cmd="if pm2 describe $q_name >/dev/null 2>&1; then pm2 delete $q_name >/dev/null 2>&1 || true; fi; $command_text"
  run_shell_step "PM2 start/restart ($BUILD_PM2_NAME)" "$replace_cmd"
}

check_port_listening() {
  local port="$1"
  if command_exists ss && ss -ltn 2>/dev/null | awk '{print $4}' | grep -E "[:.]${port}$" >/dev/null 2>&1; then
    return 0
  fi
  if command_exists lsof && lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    return 0
  fi
  if (echo >/dev/tcp/127.0.0.1/"$port") >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

check_http_ready() {
  local port="$1"
  local health_path="$2"
  if command_exists curl; then
    curl -fsS --max-time 3 "http://127.0.0.1:${port}${health_path}" >/dev/null 2>&1
    return $?
  fi
  return 1
}

verify_pm2_status() {
  local pm2_name="$1"
  [[ "$(detect_pm2_status "$pm2_name")" == "online" ]]
}

verify_port_listen() {
  local port="$1"
  check_port_listening "$port"
}

verify_http_health() {
  local port="$1"
  local health_path="${2:-}"
  if [[ -z "$health_path" ]] || ! command_exists curl; then
    return 2
  fi
  check_http_ready "$port" "$health_path"
}

verify_runtime() {
  local pm2_name="$1"
  local port="$2"
  local health_path="${3:-}"

  BUILD_VERIFY_STATUS="failed"
  BUILD_VERIFY_MESSAGE="Runtime belum tervalidasi."
  BUILD_HEALTH_STATUS="failed"

  local attempts=15
  local i=1
  local last_pm2_status="not running"
  local last_port_ok="no"
  local last_http_status="skipped"
  local has_curl=0
  if command_exists curl; then
    has_curl=1
  fi

  while (( i <= attempts )); do
    last_pm2_status="$(detect_pm2_status "$pm2_name")"
    if verify_port_listen "$port"; then
      last_port_ok="yes"
    else
      last_port_ok="no"
    fi

    if [[ -n "$health_path" ]] && (( has_curl == 1 )); then
      if verify_http_health "$port" "$health_path"; then
        last_http_status="yes"
      else
        last_http_status="no"
      fi
    else
      last_http_status="skipped"
    fi

    if [[ "$last_pm2_status" == "online" && "$last_port_ok" == "yes" ]]; then
      if [[ "$last_http_status" == "yes" ]]; then
        BUILD_VERIFY_STATUS="online"
        BUILD_VERIFY_MESSAGE="PM2 online, port listen, HTTP OK di ${health_path}."
        BUILD_HEALTH_STATUS="ok"
        return 0
      fi
      if [[ "$last_http_status" == "skipped" ]]; then
        BUILD_VERIFY_STATUS="online"
        if [[ -n "$health_path" ]]; then
          BUILD_VERIFY_MESSAGE="PM2 online, port listen, HTTP check dilewati (curl tidak tersedia)."
        else
          BUILD_VERIFY_MESSAGE="PM2 online, port listen, HTTP check dilewati (health path tidak diatur)."
        fi
        BUILD_HEALTH_STATUS="skipped"
        return 0
      fi
    fi

    sleep 1
    i=$((i + 1))
  done

  if [[ -n "$health_path" && "$last_pm2_status" == "online" && "$last_port_ok" == "yes" && "$last_http_status" == "no" ]]; then
    BUILD_VERIFY_STATUS="warning"
    BUILD_VERIFY_MESSAGE="Service started but HTTP belum merespons di ${health_path} pada port ${port}."
    BUILD_HEALTH_STATUS="failed"
    return 0
  fi

  BUILD_VERIFY_STATUS="failed"
  BUILD_VERIFY_MESSAGE="PM2=${last_pm2_status}, port_listen=${last_port_ok}, http=${last_http_status}"
  BUILD_HEALTH_STATUS="failed"
  return 1
}

verify_runtime_with_feedback() {
  log_info "Verifikasi runtime..."
  if verify_runtime "$BUILD_PM2_NAME" "$BUILD_PORT" "$BUILD_HEALTH_PATH"; then
    if [[ "$BUILD_VERIFY_STATUS" == "warning" ]]; then
      printf '[gas] warning: service started but not responding on port %s\n' "$BUILD_PORT" >&2
    fi
    return 0
  fi
  return 1
}

detect_pm2_status() {
  local pm2_name="$1"
  if [[ -z "$pm2_name" ]] || ! command_exists pm2; then
    printf 'not running\n'
    return
  fi

  local described=""
  described="$(pm2 describe "$pm2_name" 2>/dev/null || true)"
  if [[ -z "$described" ]]; then
    printf 'not running\n'
    return
  fi

  local status=""
  status="$(printf '%s\n' "$described" | awk '
    BEGIN { IGNORECASE = 1 }
    /status/ {
      if ($0 ~ /online/)  { print "online";  exit }
      if ($0 ~ /stopped/) { print "stopped"; exit }
      if ($0 ~ /errored/) { print "errored"; exit }
    }
  ')"

  if [[ -n "$status" ]]; then
    printf '%s\n' "$status"
  else
    printf 'not running\n'
  fi
}
