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
  validate_domain_name "$domain" || die "Domain tidak valid: $domain"

  require_command certbot "certbot tidak ditemukan. Install certbot dulu atau gunakan --ssl no."

  local q_domain
  q_domain="$(to_shell_quoted "$domain")"
  run_privileged_shell "certbot --nginx -d $q_domain"
}
