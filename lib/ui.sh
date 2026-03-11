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
  # gum input terlihat duplikat/kosong di beberapa terminal (tmux/ssh env tertentu).
  # Untuk stabilitas, input teks pakai prompt Bash biasa.

  if [[ -n "$default_value" ]]; then
    printf '%s (kosong = pakai default: %s): ' "$prompt" "$default_value" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi

  local value=""
  read -r value || true

  if [[ -z "$value" ]]; then
    printf '%s\n' "$default_value"
  else
    printf '%s\n' "$value"
  fi
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

