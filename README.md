# gas-cli

CLI sederhana untuk build dan run project **Go** atau **Svelte** via PM2, dengan mode interactive (inline terminal) dan mode non-interactive untuk CI/CD.

## Fitur tahap awal

- `gas build`
- `gas help`
- Interactive UX dengan `gum` jika tersedia
- Fallback plain terminal tanpa popup box
- Metadata global SQLite di `~/.config/gas/apps.db`

## Struktur project

- `bin/gas` - executable utama CLI
- `install.sh` - setup symlink ke `/usr/local/bin/gas`
- `.gitignore`
- `README.md`

## Prasyarat runtime

- Bash 4+
- `pm2`
- `sqlite3` (untuk metadata global)
- `go` (untuk build type Go)
- `node` + `npm` (untuk build type Svelte)
- `gum` (opsional, untuk interactive UI yang lebih clean)

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
gas build --no-ui --type go --pm2-name diraaax-api --git-pull yes --yes
gas build --no-ui --type svelte --port 4001 --pm2-name diraaax-web --run-mode ecosystem --git-pull yes --yes
```

## Build flags

- `--type go|svelte`
- `--port <port>`
- `--pm2-name <name>`
- `--git-pull yes|no`
- `--run-mode ecosystem|direct`
- `--no-ui`
- `--yes`

## Catatan perilaku

- `gas build` otomatis deteksi path project dari current directory.
- `git pull` bersifat opsional; kalau gagal akan tampil warning yang jelas.
- Go:
  - baca `PORT` dari `.env` / `.env.production` (kalau ada)
  - deteksi target `main.go` atau `cmd/*/main.go`
  - build binary ke `.gas/bin/`
  - start/restart app via PM2
- Svelte:
  - jalankan `npm install` dan `npm run build`
  - run mode `ecosystem` atau `direct`
  - start/restart app via PM2
- Metadata build disimpan global di `~/.config/gas/apps.db` (dengan migrasi kolom ringan).
