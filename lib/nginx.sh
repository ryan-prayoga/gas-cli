# shellcheck shell=bash
# Nginx domain management helpers.

nginx_site_available_path() {
  local domain="$1"
  printf '/etc/nginx/sites-available/%s\n' "$domain"
}

nginx_site_enabled_path() {
  local domain="$1"
  printf '/etc/nginx/sites-enabled/%s\n' "$domain"
}

is_root_user() {
  [[ "$(id -u)" -eq 0 ]]
}

run_privileged_shell() {
  local command_text="$1"
  if is_root_user; then
    bash -lc "$command_text"
    return
  fi

  if command_exists sudo; then
    sudo bash -lc "$command_text"
    return
  fi

  die "Butuh akses root/sudo untuk mengelola nginx."
}

validate_domain_name() {
  local domain="$1"
  [[ -n "$domain" ]] || return 1
  [[ "$domain" =~ ^[A-Za-z0-9.-]+$ ]] || return 1
  [[ "$domain" == *.* ]] || return 1
  [[ "$domain" != .* ]] || return 1
  [[ "$domain" != *..* ]] || return 1
  return 0
}

ensure_nginx_installed() {
  require_command nginx "nginx tidak ditemukan. Install nginx dulu."
}

nginx_site_exists() {
  local domain="$1"
  local available_path
  available_path="$(nginx_site_available_path "$domain")"
  [[ -f "$available_path" || -L "$available_path" ]]
}

nginx_read_site_config() {
  local domain="$1"
  local available_path
  available_path="$(nginx_site_available_path "$domain")"
  [[ -f "$available_path" ]] || return 1
  cat "$available_path"
}

nginx_backup_site() {
  local domain="$1"
  local available_path
  available_path="$(nginx_site_available_path "$domain")"
  [[ -f "$available_path" ]] || return 1

  local backup_path="${available_path}.bak.$(date +%Y%m%d%H%M%S)"
  local q_available q_backup
  q_available="$(to_shell_quoted "$available_path")"
  q_backup="$(to_shell_quoted "$backup_path")"
  run_privileged_shell "cp $q_available $q_backup"
  printf '%s\n' "$backup_path"
}

write_nginx_config_content() {
  local domain="$1"
  local content="$2"
  local mode="${3:-644}"

  validate_domain_name "$domain" || die "Domain tidak valid: $domain"

  local available_path
  available_path="$(nginx_site_available_path "$domain")"

  local tmp_file
  tmp_file="$(mktemp)"
  printf '%s\n' "$content" > "$tmp_file"

  local q_tmp q_path q_mode
  q_tmp="$(to_shell_quoted "$tmp_file")"
  q_path="$(to_shell_quoted "$available_path")"
  q_mode="$(to_shell_quoted "$mode")"

  run_privileged_shell "install -m $q_mode $q_tmp $q_path"
  rm -f "$tmp_file"

  printf '%s\n' "$available_path"
}

write_nginx_proxy_config() {
  local domain="$1"
  local port="$2"

  validate_domain_name "$domain" || die "Domain tidak valid: $domain"
  validate_port "$port" || die "Port tidak valid untuk nginx proxy: $port"

  local available_path
  available_path="$(nginx_site_available_path "$domain")"

  local tmp_file
  tmp_file="$(mktemp)"

  cat > "$tmp_file" <<EOF2
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};

    location / {
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_pass http://127.0.0.1:${port};
    }
}
EOF2

  local q_tmp q_path
  q_tmp="$(to_shell_quoted "$tmp_file")"
  q_path="$(to_shell_quoted "$available_path")"

  run_privileged_shell "install -m 644 $q_tmp $q_path"
  rm -f "$tmp_file"

  printf '%s\n' "$available_path"
}

enable_nginx_site() {
  local domain="$1"
  local available_path enabled_path
  available_path="$(nginx_site_available_path "$domain")"
  enabled_path="$(nginx_site_enabled_path "$domain")"

  local q_available q_enabled
  q_available="$(to_shell_quoted "$available_path")"
  q_enabled="$(to_shell_quoted "$enabled_path")"

  run_privileged_shell "ln -sfn $q_available $q_enabled"
}

disable_nginx_site() {
  local domain="$1"
  local enabled_path
  enabled_path="$(nginx_site_enabled_path "$domain")"
  local q_enabled
  q_enabled="$(to_shell_quoted "$enabled_path")"
  run_privileged_shell "rm -f $q_enabled"
}

remove_nginx_site() {
  local domain="$1"
  local available_path enabled_path
  available_path="$(nginx_site_available_path "$domain")"
  enabled_path="$(nginx_site_enabled_path "$domain")"

  local q_available q_enabled
  q_available="$(to_shell_quoted "$available_path")"
  q_enabled="$(to_shell_quoted "$enabled_path")"

  run_privileged_shell "rm -f $q_enabled $q_available"
}

disable_nginx_default_site() {
  local default_available="/etc/nginx/sites-available/default"
  local default_enabled="/etc/nginx/sites-enabled/default"
  local q_available q_enabled
  q_available="$(to_shell_quoted "$default_available")"
  q_enabled="$(to_shell_quoted "$default_enabled")"
  run_privileged_shell "rm -f $q_enabled"
  if [[ -f "$default_available" ]]; then
    local backup_path="${default_available}.bak.$(date +%Y%m%d%H%M%S)"
    run_privileged_shell "cp $q_available $(to_shell_quoted "$backup_path")" || true
  fi
}

write_nginx_named_config_path() {
  local filename="$1"
  printf '/etc/nginx/sites-available/%s\n' "$filename"
}

enable_nginx_named_config() {
  local filename="$1"
  local available_path enabled_path
  available_path="$(write_nginx_named_config_path "$filename")"
  enabled_path="/etc/nginx/sites-enabled/$filename"

  local q_available q_enabled
  q_available="$(to_shell_quoted "$available_path")"
  q_enabled="$(to_shell_quoted "$enabled_path")"

  run_privileged_shell "ln -sfn $q_available $q_enabled"
}

write_nginx_named_config_content() {
  local filename="$1"
  local content="$2"
  local mode="${3:-644}"
  local target_path
  target_path="$(write_nginx_named_config_path "$filename")"

  local tmp_file
  tmp_file="$(mktemp)"
  printf '%s\n' "$content" > "$tmp_file"

  local q_tmp q_path q_mode
  q_tmp="$(to_shell_quoted "$tmp_file")"
  q_path="$(to_shell_quoted "$target_path")"
  q_mode="$(to_shell_quoted "$mode")"
  run_privileged_shell "install -m $q_mode $q_tmp $q_path"
  rm -f "$tmp_file"

  printf '%s\n' "$target_path"
}

write_nginx_catchall_444() {
  local include_https="${1:-no}"
  local filename="gas-catchall-444"
  local content
  content="server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 444;
}"
  if [[ "$include_https" == "yes" ]]; then
    content="${content}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;
    ssl_reject_handshake on;
    return 444;
}"
  fi
  write_nginx_named_config_content "$filename" "$content" >/dev/null
  enable_nginx_named_config "$filename"
}

nginx_test_config() {
  run_privileged_shell "nginx -t"
}

nginx_reload_service() {
  if run_privileged_shell "systemctl reload nginx"; then
    return 0
  fi
  if run_privileged_shell "service nginx reload"; then
    return 0
  fi
  run_privileged_shell "nginx -s reload"
}

nginx_test_and_reload() {
  nginx_test_config
  nginx_reload_service
}

install_domain_ssl_certbot() {
  local domain="$1"
  shift || true
  validate_domain_name "$domain" || die "Domain tidak valid: $domain"

  require_command certbot "certbot tidak ditemukan. Install certbot dulu atau gunakan --ssl no."

  local -a domains=("$domain")
  while [[ $# -gt 0 ]]; do
    validate_domain_name "$1" || die "Domain tidak valid: $1"
    domains+=("$1")
    shift
  done

  local certbot_cmd="certbot --nginx --non-interactive --redirect"
  local item=""
  for item in "${domains[@]}"; do
    certbot_cmd+=" -d $(to_shell_quoted "$item")"
  done
  certbot_cmd+=" --agree-tos --register-unsafely-without-email"
  run_privileged_shell "$certbot_cmd"
}
