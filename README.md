# gas-cli

CLI Bash untuk build dan run project **Go** dan **Node web ecosystem** (SvelteKit/Next/Nuxt/Vite/Node generic) via PM2, dengan mode interactive (inline terminal) dan mode non-interactive untuk CI/CD.

## Fitur utama

- `gas build`
- `gas deploy`
- `gas deploy list`
- `gas deploy remove`
- `gas deploy doctor`
- `gas deploy preview`
- `gas domain` sebagai legacy alias yang diarahkan ke engine deploy baru
- `gas info`
- `gas list`
- `gas help`
- Stack detection otomatis (Go, SvelteKit, Next.js, Nuxt, Vite, Node, Unknown)
- Ecosystem config auto-detect (`ecosystem.config.*`, `pm2.config.*`)
- Strategy build/run yang bisa dipilih (`auto`, `ecosystem`, `node-entry`, `npm-start`, `npm-preview`)
- Interactive UX dengan `gum` jika tersedia
- Fallback plain terminal tanpa popup box
- Metadata global SQLite di `~/.config/gas/apps.db`
- Wizard deploy Nginx berbasis metadata app `gas`

## Struktur project

```text
gas-cli/
├── bin/
│   └── gas
├── lib/
│   ├── core.sh
│   ├── ui.sh
│   ├── db.sh
│   ├── detect.sh
│   ├── ecosystem.sh
│   ├── nginx.sh
│   ├── pm2.sh
│   ├── build.sh
│   ├── deploy.sh
│   ├── help.sh
│   └── commands.sh
├── install.sh
├── README.md
└── .gitignore
```

Ringkas tanggung jawab:
- `bin/gas`: entrypoint, source modul, panggil `main`
- `lib/core.sh`: global state + helper umum
- `lib/ui.sh`: prompt interaktif/fallback
- `lib/detect.sh`: deteksi stack/env/target
- `lib/ecosystem.sh`: deteksi/parse/generate ecosystem config
- `lib/nginx.sh`: helper Nginx + file config
- `lib/pm2.sh`: helper PM2 + runtime verification
- `lib/build.sh`: flow `gas build`
- `lib/deploy.sh`: wizard deploy, preview, list, remove, doctor
- `lib/db.sh`: metadata SQLite
- `lib/help.sh`: output help
- `lib/commands.sh`: dispatcher command

## Prasyarat runtime

- Bash 4+
- `pm2` (wajib untuk run)
- `sqlite3` (wajib untuk metadata `info/list`)
- `nginx` (wajib untuk `gas deploy`)
- `certbot` + `python3-certbot-nginx` (opsional, untuk SSL mode `certbot-nginx`)
- `openssl` (direkomendasikan untuk deploy/SSL)
- `go` (jika build project Go)
- `node` + `npm` (jika build project Node/web)
- `gum` (opsional untuk UX interaktif lebih rapi)
- `curl` (opsional, untuk HTTP verify runtime)

## Install

```bash
chmod +x install.sh
./install.sh
```

Setelah itu, command `gas` bisa dipakai global.

## Pemakaian

```bash
gas help
gas build
gas deploy
gas info
gas list

gas build --no-ui --type go --pm2-name diraaax-api --git-pull yes --yes
gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy auto --git-pull no --yes
gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy ecosystem --reuse-ecosystem yes --git-pull no --yes
gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --health-path /health --strategy npm-start --git-pull no --yes

gas deploy --no-ui --app marbot-web --domain app.example.com --mode single-app --ssl certbot-nginx --yes
gas deploy --no-ui --frontend diraaax-frontend --backend diraaax-backend --domain app.example.com --mode frontend-backend-split --uploads /home/ubuntu/app/uploads --ssl certbot-nginx --yes
gas deploy preview --no-ui --app marbot-web --domain app.example.com --mode single-app
gas deploy list
gas deploy remove --domain app.example.com --yes
gas deploy doctor
```

## Build flags

- `--type go|node-web`
- `--port <port>`
- `--pm2-name <name>`
- `--health-path <path>`
- `--git-pull yes|no`
- `--strategy auto|ecosystem|node-entry|npm-preview|npm-start`
- `--reuse-ecosystem yes|no`
- `--run-mode ecosystem|direct` (legacy alias)
- `--svelte-strategy ...` (legacy alias)
- `--no-ui`
- `--yes`

## Deploy singkat

`gas deploy` adalah wizard Nginx berbasis metadata dari `gas build`.

Flow umumnya:
- pilih app dari metadata `~/.config/gas/apps.db`
- input domain utama + alias + canonical host
- pilih mode deploy:
  - `single-app`
  - `frontend-backend-split`
  - `custom-multi-location`
  - `static-only`
  - `redirect-only`
  - `maintenance`
- review opsi global: SSL, websocket, body size, timeout, backup, test, reload, verify, catchall
- preview config nginx
- apply config ke `/etc/nginx/sites-available/<domain>` lalu enable ke `/etc/nginx/sites-enabled/<domain>`

Mode SSL yang tersedia:
- `none`
- `certbot-nginx`
- `existing-certificate`

Contoh single-app:

```bash
gas deploy --no-ui \
  --app marbot-web \
  --domain app.example.com \
  --mode single-app \
  --ssl certbot-nginx \
  --websocket yes \
  --backup yes \
  --test yes \
  --reload yes \
  --verify yes \
  --yes
```

Contoh frontend-backend-split:

```bash
gas deploy --no-ui \
  --frontend diraaax-frontend \
  --backend diraaax-backend \
  --domain diraaax.example.com \
  --mode frontend-backend-split \
  --uploads /home/ubuntu/projects/diraaax/backend/uploads \
  --ssl certbot-nginx \
  --canonical apex \
  --yes
```

Contoh custom multi-location:

```bash
gas deploy --no-ui \
  --mode custom-multi-location \
  --domain simpeg.example.com \
  --location '/=proxy:simpeg-web' \
  --location '/api/=proxy:simpeg-api' \
  --location '/uploads/=alias:/home/ubuntu/uploads' \
  --ssl none \
  --preview \
  --yes
```

Preview / remove / doctor:

```bash
gas deploy preview --no-ui --app marbot-web --domain app.example.com --mode single-app
gas deploy list
gas deploy remove --domain app.example.com --yes
gas deploy doctor
```

Smoke preview lokal:

```bash
./scripts/smoke-deploy-preview.sh
```

Script ini:
- membuat `HOME` sementara
- mengisi fixture metadata app ke SQLite
- menjalankan preview untuk mode `single-app`, `frontend-backend-split`, dan `custom-multi-location`
- tidak menyentuh nginx sistem

Catatan SSL dan DNS:
- Mode `certbot-nginx` butuh domain resolve ke server target.
- Port 80/443 harus bisa diakses dari internet untuk challenge Let’s Encrypt.
- `gas deploy` akan memperingatkan kalau domain belum resolve dari server saat memilih Certbot.
- Untuk sertifikat existing, gunakan `--ssl existing-certificate --ssl-cert <path> --ssl-key <path>`.

## Catatan perilaku

- `gas build` akan menampilkan deteksi stack sebelum prompt lain.
- Urutan interaktif: detect stack -> git pull -> ecosystem config -> strategy -> PM2 name/port -> summary -> execute.
- Input kosong pada prompt akan memakai nilai default yang ditampilkan.
- Sesudah run, dilakukan verifikasi runtime (PM2 status + port listen + HTTP localhost jika `curl` tersedia).
- Jika `--health-path` diisi, verifikasi HTTP diarahkan ke path itu; jika kosong, fallback ke PM2 status + port listen.
- Metadata build disimpan global di `~/.config/gas/apps.db` dengan migrasi kolom ringan.
- Metadata deploy disimpan di tabel `deployments` dan tetap menjaga tabel `domains` untuk kompatibilitas lama.
- `gas domain` tetap tersedia untuk kompatibilitas, tapi sekarang hanya menjadi adapter ke flow `gas deploy`.
