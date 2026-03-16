# shellcheck shell=bash
# Help and overview rendering.

print_help_plain() {
  cat <<EOF
gas v$CLI_VERSION

Perintah:
  gas build [options]
  gas deploy [options]
  gas deploy <list|remove|doctor|preview> [options]
  gas info
  gas list
  gas restart [pm2-name]
  gas logs [pm2-name]
  gas rebuild [options]
  gas remove [options]
  gas doctor [options]
  gas domain <add|remove|list>
  gas help

Build options:
  --type go|node-web
  --port <port>
  --pm2-name <name>
  --health-path <path>
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
  gas deploy
  gas build --no-ui --type go --pm2-name diraaax-api --git-pull yes --yes
  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy auto --git-pull no --yes
  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy ecosystem --reuse-ecosystem yes --git-pull no --yes

Detail per command:
  gas build --help
  gas deploy --help
  gas info --help
  gas list --help
  gas restart --help
  gas logs --help
  gas rebuild --help
  gas remove --help
  gas doctor --help
  gas domain --help
EOF
}

print_deploy_help_plain() {
  cat <<EOF
gas deploy - Wizard deploy Nginx untuk app yang dikelola gas

Pemakaian:
  gas deploy
  gas deploy add [options]
  gas deploy preview [options]
  gas deploy list
  gas deploy remove --domain <domain>
  gas deploy doctor

Wizard utama:
  - pilih app dari metadata gas
  - pilih domain, alias, dan canonical host
  - pilih mode deploy + routing
  - atur SSL, backup, test, reload, verify
  - preview config nginx
  - apply config dan simpan metadata deployment

Mode deploy:
  --mode single-app
    Semua request diarahkan ke satu app/upstream.

  --mode frontend-backend-split
    Route / ke frontend dan backend preserve-path default di /api/.

  --mode custom-multi-location
    Tambah beberapa location custom satu per satu atau via --location.

  --mode static-only
    Serve file static dari root directory.

  --mode redirect-only
    Domain ini hanya redirect ke target lain.

  --mode maintenance
    Tampilkan halaman maintenance statis sementara.

Mode SSL:
  --ssl none
    Deploy HTTP saja.

  --ssl certbot-nginx
    Gunakan Certbot plugin nginx untuk membuat/mengelola sertifikat HTTPS.

  --ssl existing-certificate
    Pakai file sertifikat yang sudah ada via --ssl-cert dan --ssl-key.

Flag penting:
  --domain <domain>
    Domain utama site ini.

  --app <pm2-name>
    App default untuk mode single-app.

  --frontend <pm2-name>
    App frontend untuk route /.

  --backend <pm2-name>
    App backend untuk route backend split.

  --backend-route <path>
    Public path prefix on Nginx that routes traffic to the backend.
    Example: /api/

  --backend-base-path <path>
    Base path expected by the backend application.
    Example: /api or /api/v1

  --backend-strip-prefix yes|no
    Whether the public backend route prefix should be removed before proxying to the upstream backend.
    Default: no.

  --alias-domain <domain>
    Tambah alias domain lain. Bisa dipakai berulang.

  --www yes|no
    Tambahkan alias www otomatis.

  --canonical apex|www|none|custom
    Pilih host utama, dan redirect host alternatif ke host utama.

  --canonical-host <domain>
    Host utama jika --canonical custom.

  --uploads <path>
    Alias static directory, cocok untuk file upload publik.

  --location '<path>=proxy:<app|host:port>'
  --location '<path>=alias:<dir>'
  --location '<path>=root:<dir>'
  --location '<path>=redirect:<url>'
  --location '<path>=return:<code>:<text>'
    Tambah location custom untuk mode custom-multi-location.

  --upstream-host <host>
    Host upstream default untuk proxy_pass. Default: 127.0.0.1

  --websocket yes|no
    Tambahkan header Upgrade/Connection untuk app yang butuh websocket.

  --client-max-body-size <size>
    Batas ukuran request body, mis. 10m, 50m, 100m.

  --timeout <seconds>
    Waktu tunggu proxy untuk connect/read/send.

  --gzip on|off
    Preset gzip dasar.

  --security-headers basic|strict|off
    Preset header keamanan umum.

  --static-cache basic|aggressive|off
    Preset cache header untuk location static alias/root.

  --dry-run
    Generate dan tampilkan config tanpa menulis file atau reload nginx.

  --preview
    Tampilkan config hasil generate sebelum apply.

  --save-preview <path|temp>
    Simpan hasil preview ke file.

  --backup yes|no
    Simpan backup config lama sebelum overwrite.

  --reuse-existing yes|no
    Jika config domain sudah ada, izinkan update/overwrite.

  --test yes|no
    Jalankan nginx -t sebelum reload.

  --reload yes|no
    Reload nginx otomatis jika config valid.

  --verify yes|no
    Jalankan verifikasi lokal/domain setelah deploy selesai.

  --catchall yes|no
    Buat/atur default server return 444 untuk request tidak dikenal.

  --disable-default-site yes|no
    Disable site default nginx.

  --force-https yes|no
    Redirect HTTP ke HTTPS jika SSL aktif.

  --access-log yes|no
    Aktif/nonaktif access log site.

  --error-page-root <dir>
    Root directory untuk halaman error 50x custom.

  --keep-old-config yes|no
    Simpan rollback point config lama sesudah deploy.

  --no-ui
  --yes
  --help

Contoh:
  gas deploy
  gas deploy --no-ui --app diraaax-frontend --domain diraaax.ryannn.net --mode single-app --ssl certbot-nginx --yes
  gas deploy --no-ui --frontend diraaax-frontend --backend diraaax-backend --domain diraaax.ryannn.net --mode frontend-backend-split --uploads /home/ubuntu/projects/diraaax/backend/uploads --ssl certbot-nginx --yes
  gas deploy --no-ui --frontend diraaax-frontend --backend diraaax-backend --domain diraaax.ryannn.net --mode frontend-backend-split --backend-route /api/ --backend-base-path / --backend-strip-prefix yes --yes
  gas deploy --no-ui --mode custom-multi-location --domain simpeg.ryannn.net --location '/=proxy:simpeg-web' --location '/api/=proxy:simpeg-api' --location '/uploads/=alias:/home/ubuntu/uploads' --ssl none --preview --yes

Catatan penting:
  - Default GAS untuk backend split adalah preserve path.
  - Prefix stripping hanya aktif jika --backend-strip-prefix yes.
EOF
}

print_deploy_list_help_plain() {
  cat <<EOF
gas deploy list - Tampilkan daftar site/domain yang dikelola gas

Yang ditampilkan:
  - Domain utama
  - Server type
  - Deploy mode
  - SSL mode
  - Status enabled
  - Updated at
  - Primary app

Opsi:
  --help
  --no-ui
EOF
}

print_deploy_remove_help_plain() {
  cat <<EOF
gas deploy remove - Hapus config site/domain nginx yang dikelola gas

Pemakaian:
  gas deploy remove --domain app.example.com
  gas deploy remove app.example.com

Opsi:
  --domain <domain>
    Domain target yang mau dihapus.

  --remove-enabled yes|no
    Hapus symlink enabled site. Default: yes

  --remove-config yes|no
    Hapus file config di sites-available. Default: yes

  --remove-test yes|no
    Jalankan nginx -t sesudah remove. Default: yes

  --remove-reload yes|no
    Reload nginx sesudah remove. Default: yes

  --no-ui
  --yes
  --help
EOF
}

print_deploy_doctor_help_plain() {
  cat <<EOF
gas deploy doctor - Cek dependency deploy dan readiness server

Yang dicek:
  nginx, certbot, python3-certbot-nginx, openssl, pm2, sqlite3, gum, curl, ss/iproute2, git
  plus privilege root/sudo dan indikasi listener lokal port 80/443

Opsi:
  --help
  --no-ui
EOF
}

print_deploy_preview_help_plain() {
  cat <<EOF
gas deploy preview - Generate preview config nginx tanpa apply

Pemakaian:
  gas deploy preview --app marbot-web --domain app.example.com --mode single-app
  gas deploy preview --mode custom-multi-location --domain api.example.com --location '/=proxy:marbot-web'
  gas deploy preview --frontend web --backend api --domain app.example.com --mode frontend-backend-split --backend-route /api/ --backend-strip-prefix no

Flag tambahan:
  --save-preview <path|temp>
    Simpan hasil preview ke file.

  --dry-run
    Pastikan tidak ada write/reload.

Lihat juga:
  gas deploy --help
EOF
}

print_info_help_plain() {
  cat <<EOF
gas info - Tampilkan metadata build project saat ini

Yang ditampilkan:
  - Folder
  - Stack
  - PM2 name
  - Port
  - Strategy
  - Deps mode
  - Last build
  - PM2 status (online, stopped, errored, not running)

Opsi:
  --help
  --no-ui
EOF
}

print_list_help_plain() {
  cat <<EOF
gas list - Tampilkan daftar semua project yang pernah dibuild

Yang ditampilkan:
  - PM2 name
  - Stack
  - Port
  - Updated
  - Path

Opsi:
  --help
  --no-ui
EOF
}

print_restart_help_plain() {
  cat <<EOF
gas restart - Restart PM2 app

Pemakaian:
  gas restart
  gas restart <pm2-name>

Perilaku:
  - Default: ambil PM2 name dari metadata folder saat ini
  - Jika argumen pm2-name diberikan, nama itu yang dipakai

Opsi:
  --help
  --no-ui
EOF
}

print_logs_help_plain() {
  cat <<EOF
gas logs - Lihat log PM2 app

Pemakaian:
  gas logs
  gas logs <pm2-name>

Perilaku:
  - Default: ambil PM2 name dari metadata folder saat ini
  - Jika argumen pm2-name diberikan, nama itu yang dipakai

Opsi:
  --help
  --no-ui
EOF
}

print_rebuild_help_plain() {
  cat <<EOF
gas rebuild - Rebuild project memakai metadata terakhir

Yang dilakukan:
  - Load stack/strategy/port/pm2-name dari metadata project saat ini
  - Jalankan ulang flow gas build dengan konfigurasi tersebut
  - Default git pull: yes jika folder git repo, kalau tidak no

Opsi:
  --git-pull yes|no
  --no-ui
  --yes
  --help
EOF
}

print_remove_help_plain() {
  cat <<EOF
gas remove - Hapus PM2 app + metadata project saat ini

Yang dilakukan:
  - Ambil PM2 name dari metadata folder saat ini
  - Konfirmasi dulu (mode interaktif)
  - pm2 delete <pm2-name>
  - Hapus metadata project dari database gas

Opsi:
  --no-ui
  --yes
  --help
EOF
}

print_doctor_help_plain() {
  cat <<EOF
gas doctor - Cek dependency environment server

Yang dicek:
  node, npm, pnpm, yarn, go, pm2, sqlite3, gum, git

Opsi:
  --help
  --no-ui
EOF
}

print_domain_help_plain() {
  cat <<EOF
gas domain - Setup domain nginx untuk app yang dikelola gas

Catatan:
  Command ini legacy alias.
  Untuk flow deploy yang lebih lengkap, pakai: gas deploy

Subcommand:
  gas domain add <domain> [--app <pm2-name>] [--port <port>] [--ssl yes|no] [--no-ui] [--yes]
  gas domain remove <domain> [--no-ui] [--yes]
  gas domain list [--no-ui]

Flow add:
  - Baca metadata app dari ~/.config/gas/apps.db
  - Pilih app target (otomatis/interaktif/--app)
  - Generate nginx config di /etc/nginx/sites-available/<domain>
  - Symlink ke /etc/nginx/sites-enabled/<domain>
  - nginx -t
  - reload nginx
  - opsional certbot --nginx -d <domain>

Catatan:
  - Perubahan nginx butuh akses root/sudo
  - Domain harus valid (contoh: app.example.com)
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
  --health-path <path>
  --git-pull yes|no
  --install-deps auto|yes|no
  --strategy auto|ecosystem|node-entry|npm-preview|npm-start
  --run-mode ecosystem|direct   (legacy alias)
  --svelte-strategy auto|preview|direct|ecosystem|adapter-node  (legacy alias)
  --reuse-ecosystem yes|no
  --no-ui
  --yes
  --help

Catatan health check:
  --health-path /health
    Jika diisi, verifikasi runtime akan curl ke path itu.
    Jika kosong, gas fallback ke PM2 online + port listen saja.

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
  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --health-path /health --strategy npm-start --git-pull no --yes
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
    printf '  --health-path <path>\n'
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
    gum style --bold "Catatan health check"
    printf '  --health-path /health\n'
    printf '    Jika diisi, verifikasi runtime akan curl ke path itu\n'
    printf '    Jika kosong, gas fallback ke PM2 online + port listen saja\n'
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
    printf '  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --health-path /health --strategy npm-start --git-pull no --yes\n'
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
  deploy   Wizard deploy nginx (add/list/remove/doctor/preview)
  info     Lihat metadata build project pada folder saat ini
  list     Lihat daftar semua project yang pernah dibuild
  restart  Restart PM2 app dari metadata atau pm2-name manual
  logs     Tampilkan log PM2 app dari metadata atau pm2-name manual
  rebuild  Build ulang pakai metadata build terakhir
  remove   Hapus PM2 app + metadata project saat ini
  doctor   Cek dependency environment server
  domain   Legacy alias setup domain nginx (add/remove/list)
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
    printf '  deploy   Wizard deploy nginx (add/list/remove/doctor/preview)\n'
    printf '  info     Lihat metadata build project pada folder saat ini\n'
    printf '  list     Lihat daftar semua project yang pernah dibuild\n'
    printf '  restart  Restart PM2 app dari metadata atau pm2-name manual\n'
    printf '  logs     Tampilkan log PM2 app dari metadata atau pm2-name manual\n'
    printf '  rebuild  Build ulang pakai metadata build terakhir\n'
    printf '  remove   Hapus PM2 app + metadata project saat ini\n'
    printf '  doctor   Cek dependency environment server\n'
    printf '  domain   Legacy alias setup domain nginx (add/remove/list)\n'
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
    gum style "CLI build + deploy helper untuk project Go dan Node ecosystem"
    printf '\n'
    gum style --bold "Perintah"
    printf '  gas build [options]\n'
    printf '  gas deploy [options]\n'
    printf '  gas deploy <list|remove|doctor|preview> [options]\n'
    printf '  gas info\n'
    printf '  gas list\n'
    printf '  gas restart [pm2-name]\n'
    printf '  gas logs [pm2-name]\n'
    printf '  gas rebuild [options]\n'
    printf '  gas remove [options]\n'
    printf '  gas doctor [options]\n'
    printf '  gas domain <add|remove|list>\n'
    printf '  gas help\n'
    printf '\n'
    gum style --bold "Build options"
    printf '  --type go|node-web\n'
    printf '  --port <port>\n'
    printf '  --pm2-name <name>\n'
    printf '  --health-path <path>\n'
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
    printf '  gas deploy\n'
    printf '  gas deploy --no-ui --app marbot-web --domain app.example.com --mode single-app --ssl certbot-nginx --yes\n'
    printf '  gas deploy preview --no-ui --app marbot-web --domain app.example.com --mode single-app\n'
    printf '  gas build --no-ui --type go --pm2-name diraaax-api --git-pull yes --yes\n'
    printf '  gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy auto --git-pull no --yes\n'
    printf '  gas info\n'
    printf '  gas list\n'
    printf '  gas restart\n'
    printf '  gas logs marbot-web\n'
    printf '  gas rebuild --yes\n'
    printf '  gas remove --yes\n'
    printf '  gas doctor\n'
    printf '  gas deploy list\n'
    printf '  gas domain add app.example.com --app marbot-web --ssl yes\n'
    printf '  gas domain list\n'
    printf '\n'
    gum style --bold "Detail per command"
    printf '  gas build --help\n'
    printf '  gas deploy --help\n'
    printf '  gas info --help\n'
    printf '  gas list --help\n'
    printf '  gas restart --help\n'
    printf '  gas logs --help\n'
    printf '  gas rebuild --help\n'
    printf '  gas remove --help\n'
    printf '  gas doctor --help\n'
    printf '  gas domain --help\n'
    return
  fi

  print_help_plain
}
