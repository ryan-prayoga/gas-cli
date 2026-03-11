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
  if command_exists curl; then
    curl -fsS --max-time 3 "http://127.0.0.1:${port}" >/dev/null 2>&1
    return $?
  fi
  return 1
}

verify_runtime() {
  local pm2_name="$1"
  local port="$2"
  BUILD_VERIFY_STATUS="failed"
  BUILD_VERIFY_MESSAGE="Runtime belum tervalidasi."

  local attempts=15
  local i=1
  local last_pm2_status="not running"
  local last_port_ok="no"
  local last_http_ok="skip"
  local http_available=0
  if command_exists curl; then
    http_available=1
  fi

  while (( i <= attempts )); do
    last_pm2_status="$(detect_pm2_status "$pm2_name")"
    if check_port_listening "$port"; then
      last_port_ok="yes"
    else
      last_port_ok="no"
    fi

    if (( http_available == 1 )); then
      if check_http_ready "$port"; then
        last_http_ok="yes"
      else
        last_http_ok="no"
      fi
    else
      last_http_ok="skip"
    fi

    if [[ "$last_pm2_status" == "online" && "$last_port_ok" == "yes" ]] && { [[ "$last_http_ok" == "yes" ]] || (( http_available == 0 )); }; then
      BUILD_VERIFY_STATUS="success"
      BUILD_VERIFY_MESSAGE="PM2 online, port listen, HTTP OK."
      return 0
    fi

    sleep 1
    i=$((i + 1))
  done

  BUILD_VERIFY_STATUS="failed"
  BUILD_VERIFY_MESSAGE="PM2=$last_pm2_status, port_listen=$last_port_ok, http=$last_http_ok"
  return 1
}

verify_runtime_with_feedback() {
  if (( UI_ENABLED == 1 )) && (( GUM_ENABLED == 1 )); then
    local tmp_file
    tmp_file="$(mktemp)"

    local q_name q_port q_tmp
    q_name="$(to_shell_quoted "$BUILD_PM2_NAME")"
    q_port="$(to_shell_quoted "$BUILD_PORT")"
    q_tmp="$(to_shell_quoted "$tmp_file")"

    local verify_cmd=""
    read -r -d '' verify_cmd <<EOF || true
pm2_name=$q_name
port=$q_port
tmp_file=$q_tmp
status='failed'
message='Runtime belum tervalidasi.'
pm2_status='not running'
port_ok='no'
http_ok='skip'
http_available='no'
if command -v curl >/dev/null 2>&1; then
  http_available='yes'
fi
attempt=1
while [ \$attempt -le 15 ]; do
  raw=\$(pm2 describe "\$pm2_name" 2>/dev/null || true)
  lower=\$(printf '%s\n' "\$raw" | tr '[:upper:]' '[:lower:]')
  if printf '%s\n' "\$lower" | grep -q 'online'; then
    pm2_status='online'
  elif printf '%s\n' "\$lower" | grep -q 'stopped'; then
    pm2_status='stopped'
  else
    pm2_status='not running'
  fi

  port_ok='no'
  if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | awk '{print \$4}' | grep -E "[:.]\${port}\$" >/dev/null 2>&1; then
    port_ok='yes'
  elif command -v lsof >/dev/null 2>&1 && lsof -iTCP:"\$port" -sTCP:LISTEN >/dev/null 2>&1; then
    port_ok='yes'
  elif (echo >/dev/tcp/127.0.0.1/"\$port") >/dev/null 2>&1; then
    port_ok='yes'
  fi

  if [ "\$http_available" = "yes" ]; then
    http_ok='no'
    if curl -fsS --max-time 3 "http://127.0.0.1:\$port" >/dev/null 2>&1; then
      http_ok='yes'
    fi
  else
    http_ok='skip'
  fi

  if [ "\$pm2_status" = "online" ] && [ "\$port_ok" = "yes" ] && { [ "\$http_ok" = "yes" ] || [ "\$http_available" = "no" ]; }; then
    status='success'
    message='PM2 online, port listen, HTTP OK.'
    break
  fi

  attempt=\$((attempt + 1))
  sleep 1
done

if [ "\$status" != "success" ]; then
  message="PM2=\$pm2_status, port_listen=\$port_ok, http=\$http_ok"
fi

printf '%s\t%s\n' "\$status" "\$message" > "\$tmp_file"
[ "\$status" = "success" ]
EOF

    if ! run_shell_step "Verifikasi runtime" "$verify_cmd"; then
      true
    fi

    IFS=$'\t' read -r BUILD_VERIFY_STATUS BUILD_VERIFY_MESSAGE < "$tmp_file" || true
    rm -f "$tmp_file"
    [[ "${BUILD_VERIFY_STATUS:-failed}" == "success" ]]
    return
  fi

  log_info "Verifikasi runtime..."
  verify_runtime "$BUILD_PM2_NAME" "$BUILD_PORT"
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
    }
  ')"

  if [[ -n "$status" ]]; then
    printf '%s\n' "$status"
  else
    printf 'not running\n'
  fi
}

