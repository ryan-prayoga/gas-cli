#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SOURCE_BIN="$SCRIPT_DIR/bin/gas"
TARGET_BIN="/usr/local/bin/gas"

log() {
  printf '[install] %s\n' "$*"
}

die() {
  printf '[install][error] %s\n' "$*" >&2
  exit 1
}

[[ -f "$SOURCE_BIN" ]] || die "File tidak ditemukan: $SOURCE_BIN"

chmod +x "$SOURCE_BIN"
log "Set executable: $SOURCE_BIN"

if [[ -L "$TARGET_BIN" ]]; then
  current_target="$(readlink "$TARGET_BIN" || true)"
  if [[ "$current_target" == "$SOURCE_BIN" ]]; then
    log "Symlink sudah benar: $TARGET_BIN -> $SOURCE_BIN"
    exit 0
  fi
fi

if [[ -w "$(dirname "$TARGET_BIN")" ]]; then
  ln -sfn "$SOURCE_BIN" "$TARGET_BIN"
else
  if command -v sudo >/dev/null 2>&1; then
    sudo ln -sfn "$SOURCE_BIN" "$TARGET_BIN"
  else
    die "Butuh akses tulis ke $(dirname "$TARGET_BIN") atau install sudo."
  fi
fi

log "Selesai. Command 'gas' sekarang menunjuk ke: $SOURCE_BIN"
