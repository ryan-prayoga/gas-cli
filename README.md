# gas-cli

CLI Bash untuk build dan run project **Go** dan **Node web ecosystem** (SvelteKit/Next/Nuxt/Vite/Node generic) via PM2, dengan mode interactive (inline terminal) dan mode non-interactive untuk CI/CD.

## Fitur utama

- `gas build`
- `gas info`
- `gas list`
- `gas help`
- Stack detection otomatis (Go, SvelteKit, Next.js, Nuxt, Vite, Node, Unknown)
- Ecosystem config auto-detect (`ecosystem.config.*`, `pm2.config.*`)
- Strategy build/run yang bisa dipilih (`auto`, `ecosystem`, `node-entry`, `npm-start`, `npm-preview`)
- Interactive UX dengan `gum` jika tersedia
- Fallback plain terminal tanpa popup box
- Metadata global SQLite di `~/.config/gas/apps.db`

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
│   ├── pm2.sh
│   ├── build.sh
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
- `lib/pm2.sh`: helper PM2 + runtime verification
- `lib/build.sh`: flow `gas build`
- `lib/db.sh`: metadata SQLite
- `lib/help.sh`: output help
- `lib/commands.sh`: dispatcher command

## Prasyarat runtime

- Bash 4+
- `pm2` (wajib untuk run)
- `sqlite3` (wajib untuk metadata `info/list`)
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
gas info
gas list

gas build --no-ui --type go --pm2-name diraaax-api --git-pull yes --yes
gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy auto --git-pull no --yes
gas build --no-ui --type node-web --pm2-name marbot-web --port 3000 --strategy ecosystem --reuse-ecosystem yes --git-pull no --yes
```

## Build flags

- `--type go|node-web`
- `--port <port>`
- `--pm2-name <name>`
- `--git-pull yes|no`
- `--strategy auto|ecosystem|node-entry|npm-preview|npm-start`
- `--reuse-ecosystem yes|no`
- `--run-mode ecosystem|direct` (legacy alias)
- `--svelte-strategy ...` (legacy alias)
- `--no-ui`
- `--yes`

## Catatan perilaku

- `gas build` akan menampilkan deteksi stack sebelum prompt lain.
- Urutan interaktif: detect stack -> git pull -> ecosystem config -> strategy -> PM2 name/port -> summary -> execute.
- Input kosong pada prompt akan memakai nilai default yang ditampilkan.
- Sesudah run, dilakukan verifikasi runtime (PM2 status + port listen + HTTP localhost jika `curl` tersedia).
- Metadata build disimpan global di `~/.config/gas/apps.db` dengan migrasi kolom ringan.
