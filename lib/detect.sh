# shellcheck shell=bash
# Project and stack detection helpers.

extract_port_from_env_file() {
  local file="$1"
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*PORT[[:space:]]*=/ {
      sub(/^[^=]*=/, "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      gsub(/^["'"'"'"]|["'"'"'"]$/, "", $0)
      print $0
      exit
    }
  ' "$file"
}

detect_env_port() {
  local detected_port=""
  local detected_file=""
  local file=""

  for file in "$PROJECT_DIR/.env" "$PROJECT_DIR/.env.production"; do
    if [[ -f "$file" ]]; then
      local parsed_port=""
      parsed_port="$(extract_port_from_env_file "$file" || true)"
      if [[ -n "$parsed_port" ]]; then
        detected_port="$parsed_port"
        detected_file="$file"
        break
      fi
      if [[ -z "$detected_file" ]]; then
        detected_file="$file"
      fi
    fi
  done

  if [[ -z "$detected_file" ]]; then
    detected_file="$PROJECT_DIR/.env"
  fi

  printf '%s;%s\n' "$detected_port" "$detected_file"
}

upsert_env_port() {
  local file="$1"
  local port="$2"

  if [[ ! -f "$file" ]]; then
    printf 'PORT=%s\n' "$port" > "$file"
    return
  fi

  local tmp_file
  tmp_file="$(mktemp)"
  awk -v port="$port" '
    BEGIN { updated = 0 }
    {
      if ($0 ~ /^[[:space:]]*PORT[[:space:]]*=/ && updated == 0) {
        print "PORT=" port
        updated = 1
        next
      }
      print $0
    }
    END {
      if (updated == 0) {
        print "PORT=" port
      }
    }
  ' "$file" > "$tmp_file"
  mv "$tmp_file" "$file"
}

has_go_signals() {
  [[ -f "$PROJECT_DIR/go.mod" || -f "$PROJECT_DIR/main.go" ]] && return 0
  shopt -s nullglob
  local -a cmd_targets=("$PROJECT_DIR"/cmd/*/main.go)
  shopt -u nullglob
  (( ${#cmd_targets[@]} > 0 ))
}

package_json_has() {
  local pattern="$1"
  [[ -f "$PROJECT_DIR/package.json" ]] || return 1
  grep -Eqi "$pattern" "$PROJECT_DIR/package.json"
}

detect_stack() {
  local has_go=0
  local has_pkg=0
  local stack_id="unknown"
  local stack_label="Unknown"
  local stack_confidence="low"
  local stack_notes="Tidak ada indikator stack yang kuat."

  if has_go_signals; then
    has_go=1
  fi
  [[ -f "$PROJECT_DIR/package.json" ]] && has_pkg=1

  if (( has_pkg == 1 )); then
    if package_json_has '@sveltejs/kit'; then
      stack_id="sveltekit"
      stack_label="SvelteKit app"
      stack_confidence="high"
      stack_notes="package.json mengandung @sveltejs/kit."
    elif package_json_has '"next"|\\bnext\\b'; then
      stack_id="nextjs"
      stack_label="Next.js app"
      stack_confidence="high"
      stack_notes="package.json mengandung next."
    elif package_json_has '"nuxt"|\\bnuxt\\b'; then
      stack_id="nuxt"
      stack_label="Nuxt app"
      stack_confidence="high"
      stack_notes="package.json mengandung nuxt."
    elif package_json_has '"vite"|\\bvite\\b'; then
      stack_id="vite"
      stack_label="Vite app"
      stack_confidence="medium"
      stack_notes="package.json mengandung vite."
    elif (( has_go == 1 )); then
      stack_id="mixed"
      stack_label="Mixed Go + Node app"
      stack_confidence="medium"
      stack_notes="Go dan package.json terdeteksi bersamaan."
    else
      stack_id="node"
      stack_label="Node app"
      stack_confidence="medium"
      stack_notes="package.json ditemukan tanpa framework spesifik."
    fi
  elif (( has_go == 1 )); then
    stack_id="go"
    stack_label="Go app"
    stack_confidence="high"
    stack_notes="go.mod/main.go/cmd/*/main.go terdeteksi."
  fi

  BUILD_STACK_ID="$stack_id"
  BUILD_STACK_LABEL="$stack_label"
  BUILD_STACK_CONFIDENCE="$stack_confidence"
  BUILD_STACK_NOTES="$stack_notes"
}

stack_is_node_based() {
  case "$BUILD_STACK_ID" in
    sveltekit|nextjs|nuxt|vite|node|mixed) return 0 ;;
    *) return 1 ;;
  esac
}

show_detected_stack() {
  if (( UI_ENABLED == 1 )) && (( GUM_ENABLED == 1 )); then
    gum style --bold "Folder terdeteksi sebagai: $BUILD_STACK_LABEL"
    gum style --italic "confidence: $BUILD_STACK_CONFIDENCE | notes: $BUILD_STACK_NOTES"
  else
    printf 'Folder ini terdeteksi sebagai project: %s\n' "$BUILD_STACK_LABEL"
    printf '  confidence: %s\n' "$BUILD_STACK_CONFIDENCE"
    printf '  notes     : %s\n' "$BUILD_STACK_NOTES"
  fi
}

resolve_build_type() {
  if [[ -n "$BUILD_TYPE" ]]; then
    case "$BUILD_TYPE" in
      go) return ;;
      svelte|sveltekit|next|nextjs|nuxt|vite|node|node-web|web)
        BUILD_TYPE="node-web"
        return
        ;;
      *)
        die "Nilai --type tidak valid. Gunakan: go | node-web."
        ;;
    esac
  fi

  case "$BUILD_STACK_ID" in
    go)
      BUILD_TYPE="go"
      ;;
    sveltekit|nextjs|nuxt|vite|node)
      BUILD_TYPE="node-web"
      ;;
    mixed)
      if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
        BUILD_TYPE="$(ui_select 'Project mixed terdeteksi. Pilih mode build' 'node-web' node-web go)"
      else
        BUILD_TYPE="node-web"
      fi
      ;;
    unknown)
      if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
        BUILD_TYPE="$(ui_select 'Stack tidak dikenali. Pilih mode build' 'node-web' node-web go)"
      else
        die "Stack tidak dikenali. Pakai --type go atau --type node-web."
      fi
      ;;
    *)
      die "Stack terdeteksi tidak didukung: $BUILD_STACK_ID"
      ;;
  esac
}


collect_go_targets() {
  local -a targets=()

  if [[ -f "$PROJECT_DIR/main.go" ]]; then
    targets+=("./")
  fi

  local -a files=()
  shopt -s nullglob
  files=("$PROJECT_DIR"/cmd/*/main.go)
  shopt -u nullglob

  if (( ${#files[@]} > 0 )); then
    local file=""
    for file in "${files[@]}"; do
      local rel_dir=""
      rel_dir="$(dirname "${file#"$PROJECT_DIR/"}")"
      targets+=("./$rel_dir")
    done
  fi

  if (( ${#targets[@]} > 0 )); then
    local item=""
    for item in "${targets[@]}"; do
      printf '%s\n' "$item"
    done
  fi
}

resolve_go_target() {
  local -a targets=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && targets+=("$line")
  done < <(collect_go_targets)

  if (( ${#targets[@]} == 0 )); then
    die "Target Go tidak ditemukan. Perlu main.go atau cmd/*/main.go."
  fi

  if (( ${#targets[@]} == 1 )); then
    BUILD_GO_TARGET="${targets[0]}"
    return
  fi

  if (( UI_ENABLED == 1 )) && (( ASSUME_YES == 0 )); then
    BUILD_GO_TARGET="$(ui_select 'Pilih target Go untuk dibuild' "${targets[0]}" "${targets[@]}")"
  else
    BUILD_GO_TARGET="${targets[0]}"
    log_warn "Multiple target Go terdeteksi. Dipilih otomatis: $BUILD_GO_TARGET"
  fi
}

sanitize_binary_name() {
  local name="$1"
  name="${name// /-}"
  name="${name//\//-}"
  printf '%s\n' "$name"
}


detect_node_entry_file() {
  local candidates=(
    "$PROJECT_DIR/build/index.js"
    "$PROJECT_DIR/.svelte-kit/output/server/index.js"
    "$PROJECT_DIR/.output/server/index.mjs"
    "$PROJECT_DIR/dist/server/entry.mjs"
    "$PROJECT_DIR/server/index.js"
    "$PROJECT_DIR/dist/index.js"
  )
  local item=""
  for item in "${candidates[@]}"; do
    if [[ -f "$item" ]]; then
      printf '%s\n' "$item"
      return 0
    fi
  done
  return 1
}

has_valid_ecosystem_file() {
  [[ -n "$BUILD_ECOSYSTEM_FILE" && -f "$BUILD_ECOSYSTEM_FILE" ]] || return 1
  grep -Eq 'apps[[:space:]]*:' "$BUILD_ECOSYSTEM_FILE"
}

package_has_script() {
  local script="$1"
  [[ -f "$PROJECT_DIR/package.json" ]] || return 1
  node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));process.exit(p.scripts&&p.scripts[process.argv[2]]?0:1)" "$PROJECT_DIR/package.json" "$script" >/dev/null 2>&1
}

