# shellcheck shell=bash
# UI helpers with gum + plain fallback.

ui_select() {
  local prompt="$1"
  local default_value="$2"
  shift 2
  local options=("$@")

  if (( GUM_ENABLED == 1 )); then
    local chosen
    chosen="$(printf '%s\n' "${options[@]}" | gum choose --header "$prompt")"
    if [[ -z "$chosen" ]]; then
      printf '%s\n' "$default_value"
    else
      printf '%s\n' "$chosen"
    fi
    return
  fi

  local index=1
  printf '%s\n' "$prompt" >&2
  for option in "${options[@]}"; do
    if [[ "$option" == "$default_value" ]]; then
      printf '  %d) %s (default)\n' "$index" "$option" >&2
    else
      printf '  %d) %s\n' "$index" "$option" >&2
    fi
    index=$((index + 1))
  done
  printf '> ' >&2

  local input=""
  read -r input || true

  if [[ -z "$input" ]]; then
    printf '%s\n' "$default_value"
    return
  fi

  if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#options[@]} )); then
    printf '%s\n' "${options[input-1]}"
    return
  fi

  for option in "${options[@]}"; do
    if [[ "$option" == "$input" ]]; then
      printf '%s\n' "$option"
      return
    fi
  done

  log_warn "Pilihan tidak valid, pakai default: $default_value"
  printf '%s\n' "$default_value"
}

ui_input() {
  local prompt="$1"
  local default_value="${2:-}"
  # NOTE:
  # gum input terlihat duplikat/kosong di beberapa terminal (tmux/ssh env tertentu),
  # jadi input teks tetap pakai Bash read.
  # Fungsi ini sering dipakai via command substitution (stdout ditangkap variabel),
  # maka prompt interaktif harus ke /dev/tty agar tetap tampil normal.

  local value=""
  local use_tty=0
  if [[ -r /dev/tty && -w /dev/tty ]]; then
    use_tty=1
  fi

  if [[ -n "$default_value" ]]; then
    # Gunakan readline prefill jika tersedia agar Enter langsung pakai default.
    if (( use_tty == 1 )); then
      if read -r -e -i "$default_value" -p "$prompt: " value < /dev/tty > /dev/tty 2>/dev/tty; then
        printf '%s\n' "${value:-$default_value}"
        return
      fi
      printf '%s [%s]: ' "$prompt" "$default_value" > /dev/tty
      read -r value < /dev/tty || true
      printf '%s\n' "${value:-$default_value}"
      return
    fi

    printf '%s [%s]: ' "$prompt" "$default_value" >&2
  else
    if (( use_tty == 1 )); then
      printf '%s: ' "$prompt" > /dev/tty
      read -r value < /dev/tty || true
      printf '%s\n' "$value"
      return
    fi
    printf '%s: ' "$prompt" >&2
  fi

  read -r value || true

  if [[ -z "$value" ]]; then
    printf '%s\n' "$default_value"
  else
    printf '%s\n' "$value"
  fi
}

ui_confirm() {
  local prompt="$1"
  local default_value="${2:-yes}"
  local normalized_default
  normalized_default="$(normalize_yes_no "$default_value" || true)"
  if [[ -z "$normalized_default" ]]; then
    normalized_default="yes"
  fi

  if (( ASSUME_YES == 1 )); then
    [[ "$normalized_default" == "yes" ]]
    return
  fi

  if (( UI_ENABLED == 0 )); then
    [[ "$normalized_default" == "yes" ]]
    return
  fi

  if (( GUM_ENABLED == 1 )); then
    if [[ "$normalized_default" == "yes" ]]; then
      gum confirm "$prompt"
      return
    fi
    if gum confirm --default=false "$prompt"; then
      return 0
    fi
    return 1
  fi

  local answer=""
  answer="$(ui_select "$prompt" "$normalized_default" yes no)"
  [[ "$answer" == "yes" ]]
}

ui_input_optional_csv() {
  local prompt="$1"
  local default_value="${2:-}"
  local raw_value=""
  raw_value="$(ui_input "$prompt" "$default_value")"
  printf '%s\n' "$raw_value" | awk -F',' '
    {
      out=""
      for (i = 1; i <= NF; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
        if ($i != "") {
          if (out != "") out = out ","
          out = out $i
        }
      }
      print out
    }
  '
}

resolve_pm2_name() {
  if [[ -n "$BUILD_PM2_NAME" ]]; then
    return
  fi

  local default_name="${1:-$(basename "$PROJECT_DIR")}"

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    BUILD_PM2_NAME="$(ui_input 'PM2 app name' "$default_name")"
  else
    BUILD_PM2_NAME="$default_name"
  fi
}

resolve_port_input() {
  local prompt="$1"
  local default_port="$2"

  if [[ -n "$BUILD_PORT" ]]; then
    validate_port "$BUILD_PORT" || die "Port tidak valid: $BUILD_PORT"
    return
  fi

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    BUILD_PORT="$(ui_input "$prompt" "$default_port")"
  else
    BUILD_PORT="$default_port"
  fi

  validate_port "$BUILD_PORT" || die "Port tidak valid: $BUILD_PORT"
}

summary_value() {
  local value="${1:-}"
  if [[ -z "$value" ]]; then
    printf -- "-"
    return
  fi
  printf '%s' "$value"
}

print_build_summary_plain() {
  printf '\nBuild Summary\n\n'
  printf 'Folder      : %s\n' "$(summary_value "$PROJECT_DIR")"
  printf 'Stack       : %s\n' "$(summary_value "${BUILD_STACK_LABEL:-}")"
  printf 'Strategy    : %s\n' "$(summary_value "${BUILD_STRATEGY_FINAL:-${BUILD_STRATEGY:-go-binary}}")"
  printf 'PM2 name    : %s\n' "$(summary_value "$BUILD_PM2_NAME")"
  printf 'Port        : %s\n' "$(summary_value "$BUILD_PORT")"
  printf 'Deps mode   : %s\n' "$(summary_value "${BUILD_INSTALL_DEPS:-auto}")"
  printf 'Install ran : %s\n' "$(summary_value "${BUILD_INSTALL_RAN:-no}")"
  printf 'Status      : %s\n' "$(summary_value "${BUILD_VERIFY_STATUS:-unknown}")"
  printf 'Health      : %s\n' "$(summary_value "${BUILD_HEALTH_STATUS:-skipped}")"
}

print_build_summary() {
  if (( UI_ENABLED == 1 )) && (( GUM_ENABLED == 1 )); then
    gum style --bold "Build Summary"
    printf '\n'
    printf 'Folder      : %s\n' "$(summary_value "$PROJECT_DIR")"
    printf 'Stack       : %s\n' "$(summary_value "${BUILD_STACK_LABEL:-}")"
    printf 'Strategy    : %s\n' "$(summary_value "${BUILD_STRATEGY_FINAL:-${BUILD_STRATEGY:-go-binary}}")"
    printf 'PM2 name    : %s\n' "$(summary_value "$BUILD_PM2_NAME")"
    printf 'Port        : %s\n' "$(summary_value "$BUILD_PORT")"
    printf 'Deps mode   : %s\n' "$(summary_value "${BUILD_INSTALL_DEPS:-auto}")"
    printf 'Install ran : %s\n' "$(summary_value "${BUILD_INSTALL_RAN:-no}")"
    printf 'Status      : %s\n' "$(summary_value "${BUILD_VERIFY_STATUS:-unknown}")"
    printf 'Health      : %s\n' "$(summary_value "${BUILD_HEALTH_STATUS:-skipped}")"
    return
  fi

  print_build_summary_plain
}
