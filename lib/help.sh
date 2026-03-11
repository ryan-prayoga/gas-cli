# shellcheck shell=bash
# Help and overview rendering.

print_help_plain() {
  cat <<EOF
gas v$CLI_VERSION

Perintah:
  gas build [options]
  gas info
  gas list
  gas help

Build options:
  --type go|node-web
  --port <port>
  --pm2-name <name>
  --git-pull yes|no
  --install-deps auto|yes|no
  --strategy auto|ecosystem|node-entry|npm-preview|npm-start
  --run-mode ecosystem|direct              (legacy alias)
  --svelte-strategy auto|preview|direct|ecosystem|adapter-node   (legacy alias)
  --reuse-ecosystem yes|no
  --no-ui
  --yes

Catatan:
  - gas build akan deteksi stack otomatis (Go/SvelteKit/Next/Nuxt/Vite/Node/Unknown)
  - Jika ada ecosystem config, gas akan baca default name/port best effort
  - Input kosong akan memakai default yang ditampilkan di prompt

Contoh:
  gas build
  gas build --no-ui --type go --pm2-name diraaax-api --git-pull yes --yes
  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy auto --git-pull no --yes
  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy ecosystem --reuse-ecosystem yes --git-pull no --yes

Detail per command:
  gas build --help
  gas info --help
  gas list --help
EOF
}

print_info_help_plain() {
  cat <<EOF
gas info - Tampilkan metadata build project saat ini

Yang ditampilkan:
  - Metadata build berdasarkan current directory
  - Status PM2 (online, stopped, not running)

Opsi:
  --help
  --no-ui
EOF
}

print_list_help_plain() {
  cat <<EOF
gas list - Tampilkan daftar semua project yang pernah dibuild

Yang ditampilkan:
  - Project
  - Type
  - PM2 name
  - Port
  - Updated

Opsi:
  --help
  --no-ui
EOF
}

print_build_help_plain() {
  cat <<EOF
gas build - Build project Go atau Node web lalu jalankan via PM2

Yang dilakukan command ini:
  - Deteksi stack project dari current directory
  - Tawarkan git pull dulu
  - Cek ecosystem/pm2 config (jika ada) dan baca default best effort
  - Kumpulkan pilihan (type/strategy/pm2/port) lalu tampilkan summary
  - Jalankan build + run via PM2 sesuai strategy
  - Verifikasi runtime (PM2 online, port listen, HTTP localhost)
  - Simpan metadata global ke ~/.config/gas/apps.db

Opsi:
  --type go|node-web
  --port <port>
  --pm2-name <name>
  --git-pull yes|no
  --install-deps auto|yes|no
  --strategy auto|ecosystem|node-entry|npm-preview|npm-start
  --run-mode ecosystem|direct   (legacy alias)
  --svelte-strategy auto|preview|direct|ecosystem|adapter-node  (legacy alias)
  --reuse-ecosystem yes|no
  --no-ui
  --yes
  --help

Strategy:
  ecosystem  - pakai/reuse/generate ecosystem config PM2
  node-entry - jalankan entry hasil build via node
  npm-preview- jalankan npm run preview
  npm-start  - jalankan npm run start
  auto       - pilih strategy terbaik otomatis

Install dependency mode:
  auto       - install hanya jika dibutuhkan (default)
  yes        - selalu install dependency sebelum build
  no         - tidak install dependency

Contoh:
  gas build
  gas build --no-ui --type go --pm2-name diraaax-api --git-pull yes --yes
  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy auto --git-pull no --yes
  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy npm-start --git-pull no --yes
  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy node-entry --git-pull no --yes
  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy ecosystem --reuse-ecosystem yes --git-pull no --yes
  gas build --install-deps auto
  gas build --install-deps yes
  gas build --install-deps no
EOF
}

print_build_help() {
  if (( NO_UI == 0 )) && command_exists gum && is_interactive_terminal; then
    gum style --bold "gas build"
    gum style "Build project Go atau Node web lalu jalankan via PM2"
    printf '\n'
    gum style --bold "Yang dilakukan command ini"
    printf '  - Deteksi stack project dari current directory\n'
    printf '  - (Opsional) git pull sebelum build\n'
    printf '  - Cek ecosystem config dan ambil default best effort\n'
    printf '  - Build + run via PM2 sesuai strategy\n'
    printf '  - Verifikasi runtime (PM2, port, HTTP)\n'
    printf '  - Simpan metadata global ke ~/.config/gas/apps.db\n'
    printf '\n'
    gum style --bold "Opsi"
    printf '  --type go|node-web\n'
    printf '  --port <port>\n'
    printf '  --pm2-name <name>\n'
    printf '  --git-pull yes|no\n'
    printf '  --install-deps auto|yes|no\n'
    printf '  --strategy auto|ecosystem|node-entry|npm-preview|npm-start\n'
    printf '  --run-mode ecosystem|direct   (legacy alias)\n'
    printf '  --svelte-strategy auto|preview|direct|ecosystem|adapter-node (legacy alias)\n'
    printf '  --reuse-ecosystem yes|no\n'
    printf '  --no-ui\n'
    printf '  --yes\n'
    printf '  --help\n'
    printf '\n'
    gum style --bold "Strategy"
    printf '  ecosystem  - pakai/reuse/generate ecosystem config PM2\n'
    printf '  node-entry - jalankan entry hasil build via node\n'
    printf '  npm-preview- jalankan npm run preview\n'
    printf '  npm-start  - jalankan npm run start\n'
    printf '  auto       - pilih strategy terbaik otomatis\n'
    printf '\n'
    gum style --bold "Install dependency mode"
    printf '  auto       - install hanya jika dibutuhkan (default)\n'
    printf '  yes        - selalu install dependency sebelum build\n'
    printf '  no         - tidak install dependency\n'
    printf '\n'
    gum style --bold "Contoh"
    printf '  gas build\n'
    printf '  gas build --no-ui --type go --pm2-name diraaax-api --git-pull yes --yes\n'
    printf '  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy auto --git-pull no --yes\n'
    printf '  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy npm-start --git-pull no --yes\n'
    printf '  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy node-entry --git-pull no --yes\n'
    printf '  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy ecosystem --reuse-ecosystem yes --git-pull no --yes\n'
    printf '  gas build --install-deps auto\n'
    printf '  gas build --install-deps yes\n'
    printf '  gas build --install-deps no\n'
    printf '\n'
    gum style --bold "Detail per command"
    printf '  gas build --help\n'
    printf '  gas info --help\n'
    printf '  gas list --help\n'
    return
  fi

  print_build_help_plain
}

print_overview_plain() {
  cat <<EOF
gas v$CLI_VERSION

Daftar command:
  build    Build project Go/Node web dengan stack detect + strategy
  info     Lihat metadata build project pada folder saat ini
  list     Lihat daftar semua project yang pernah dibuild
  help     Tampilkan panduan lengkap command dan opsi

Untuk detail command:
  gas help
  gas <command> --help
EOF
}

print_overview() {
  if (( NO_UI == 0 )) && command_exists gum && is_interactive_terminal; then
    gum style --bold "gas v$CLI_VERSION"
    printf '\n'
    gum style --bold "Daftar command"
    printf '  build    Build project Go/Node web dengan stack detect + strategy\n'
    printf '  info     Lihat metadata build project pada folder saat ini\n'
    printf '  list     Lihat daftar semua project yang pernah dibuild\n'
    printf '  help     Tampilkan panduan lengkap command dan opsi\n'
    printf '\n'
    gum style --italic "Untuk detail command: gas help atau gas <command> --help"
    return
  fi

  print_overview_plain
}

print_help() {
  if (( NO_UI == 0 )) && command_exists gum && is_interactive_terminal; then
    gum style --bold "gas v$CLI_VERSION"
    gum style "CLI build helper untuk project Go dan Node ecosystem"
    printf '\n'
    gum style --bold "Perintah"
    printf '  gas build [options]\n'
    printf '  gas info\n'
    printf '  gas list\n'
    printf '  gas help\n'
    printf '\n'
    gum style --bold "Build options"
    printf '  --type go|node-web\n'
    printf '  --port <port>\n'
    printf '  --pm2-name <name>\n'
    printf '  --git-pull yes|no\n'
    printf '  --install-deps auto|yes|no\n'
    printf '  --strategy auto|ecosystem|node-entry|npm-preview|npm-start\n'
    printf '  --run-mode ecosystem|direct              (legacy alias)\n'
    printf '  --svelte-strategy auto|preview|direct|ecosystem|adapter-node (legacy alias)\n'
    printf '  --reuse-ecosystem yes|no\n'
    printf '  --no-ui\n'
    printf '  --yes\n'
    printf '\n'
    gum style --bold "Catatan"
    printf '  - Stack dideteksi otomatis: Go/SvelteKit/Next/Nuxt/Vite/Node/Unknown\n'
    printf '  - Ecosystem config akan dideteksi otomatis (jika ada)\n'
    printf '  - Input kosong memakai default yang ditampilkan\n'
    printf '\n'
    gum style --bold "Contoh"
    printf '  gas build\n'
    printf '  gas build --no-ui --type go --pm2-name diraaax-api --git-pull yes --yes\n'
    printf '  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy auto --git-pull no --yes\n'
    return
  fi

  print_help_plain
}
