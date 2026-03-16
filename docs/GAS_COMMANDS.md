# GAS Commands Reference

## Ringkasan Command Surface

Command yang benar-benar tersedia di codebase saat ini adalah:

- `gas build`
- `gas deploy`
- `gas deploy preview`
- `gas deploy list`
- `gas deploy remove`
- `gas deploy doctor`
- `gas info`
- `gas list`
- `gas restart`
- `gas logs`
- `gas rebuild`
- `gas remove`
- `gas doctor`
- `gas domain add`
- `gas domain remove`
- `gas domain list`
- `gas help`

`gas domain` adalah legacy alias yang meneruskan request ke engine `gas deploy`.

## Command Reference

### gas build

Deskripsi: build project Go atau Node/web, menjalankannya lewat PM2, memverifikasi runtime, lalu menyimpan metadata ke SQLite.

Usage:

```bash
gas build
gas build --no-ui --type node-web --pm2-name web --port 4001 --strategy auto --yes
```

Options:

- `--type go|node-web`
- `--port <port>`
- `--pm2-name <name>`
- `--git-pull yes|no`
- `--install-deps auto|yes|no`
- `--strategy auto|ecosystem|node-entry|npm-preview|npm-start`
- `--run-mode ecosystem|direct` (legacy alias)
- `--svelte-strategy auto|preview|direct|ecosystem|adapter-node` (legacy alias)
- `--reuse-ecosystem yes|no`
- `--no-ui`
- `--yes`

Example:

```bash
gas build
gas build --no-ui --type go --pm2-name api --port 4000 --yes
gas build --no-ui --type node-web --pm2-name web --port 4001 --strategy ecosystem --reuse-ecosystem yes --yes
```

### gas deploy

Deskripsi: wizard deploy Nginx berbasis metadata app hasil `gas build`. Default subcommand adalah `add`.

Usage:

```bash
gas deploy
gas deploy --no-ui --app web --domain app.example.com --mode single-app --ssl certbot-nginx --yes
```

Options:

- `--server <nginx>`
- `--domain <domain>`
- `--app <pm2-name>`
- `--frontend <pm2-name>`
- `--backend <pm2-name>`
- `--mode single-app|frontend-backend-split|custom-multi-location|static-only|redirect-only|maintenance`
- `--alias-domain <domain>` repeatable
- `--www yes|no`
- `--canonical apex|www|none|custom`
- `--canonical-host <domain>`
- `--ssl none|certbot-nginx|existing-certificate`
- `--ssl-cert <path>`
- `--ssl-key <path>`
- `--ssl-params <path>`
- `--http2 yes|no`
- `--force-https yes|no`
- `--websocket yes|no`
- `--client-max-body-size <size>`
- `--timeout <seconds>`
- `--gzip on|off`
- `--security-headers basic|strict|off`
- `--static-cache basic|aggressive|off`
- `--access-log yes|no`
- `--error-log <path>`
- `--error-page-root <dir>`
- `--preview`
- `--dry-run`
- `--save-preview <path|temp>`
- `--backup yes|no`
- `--test yes|no`
- `--reload yes|no`
- `--verify yes|no`
- `--verify-upstream yes|no`
- `--verify-domain yes|no`
- `--reuse-existing yes|no`
- `--catchall yes|no`
- `--catchall-https yes|no`
- `--disable-default-site yes|no`
- `--keep-old-config yes|no`
- `--upstream-host <host>`
- `--port <port>` override port app
- `--uploads <path>`
- `--uploads-cache <preset>`
- `--static-root <path>`
- `--redirect-target <url>`
- `--redirect-code <code>`
- `--maintenance-root <path>`
- `--generate-maintenance yes|no`
- `--location '<path>=<type>:<target>'` repeatable
- `--notes <text>`
- `--no-ui`
- `--yes`

Example:

```bash
gas deploy
gas deploy --no-ui --app web --domain app.example.com --mode single-app --ssl certbot-nginx --yes
gas deploy --no-ui --frontend web --backend api --domain app.example.com --mode frontend-backend-split --uploads /srv/uploads --yes
```

### gas deploy preview

Deskripsi: generate preview config Nginx tanpa apply ke sistem.

Usage:

```bash
gas deploy preview --app web --domain app.example.com --mode single-app
```

Options:

- semua opsi routing milik `gas deploy`
- `--save-preview <path|temp>`
- `--dry-run`
- `--no-ui`
- `--yes`

Example:

```bash
gas deploy preview --no-ui --app web --domain app.example.com --mode single-app
gas deploy preview --no-ui --mode custom-multi-location --domain api.example.com --location '/=proxy:web'
```

### gas deploy list

Deskripsi: menampilkan daftar deployment yang tersimpan di metadata `deployments`.

Usage:

```bash
gas deploy list
```

Options:

- `--no-ui`

Example:

```bash
gas deploy list
```

### gas deploy remove

Deskripsi: menghapus config site Nginx dan metadata deployment untuk sebuah domain.

Usage:

```bash
gas deploy remove --domain app.example.com
gas deploy remove app.example.com
```

Options:

- `--domain <domain>`
- `--remove-enabled yes|no`
- `--remove-config yes|no`
- `--remove-test yes|no`
- `--remove-reload yes|no`
- `--no-ui`
- `--yes`

Example:

```bash
gas deploy remove --domain app.example.com --yes
```

### gas deploy doctor

Deskripsi: mengecek readiness server untuk workflow deploy.

Usage:

```bash
gas deploy doctor
```

Options:

- `--no-ui`

Example:

```bash
gas deploy doctor
```

### gas info

Deskripsi: menampilkan metadata build untuk folder project saat ini.

Usage:

```bash
gas info
```

Options:

- `--no-ui`

Example:

```bash
gas info
```

### gas list

Deskripsi: menampilkan semua project yang pernah dibuild dengan `gas`.

Usage:

```bash
gas list
```

Options:

- `--no-ui`

Example:

```bash
gas list
```

### gas restart

Deskripsi: restart app PM2 berdasarkan metadata folder saat ini atau berdasarkan nama manual.

Usage:

```bash
gas restart
gas restart web
```

Options:

- `--no-ui`

Example:

```bash
gas restart
gas restart api
```

### gas logs

Deskripsi: membuka log PM2 berdasarkan metadata folder saat ini atau nama manual.

Usage:

```bash
gas logs
gas logs web
```

Options:

- `--no-ui`

Example:

```bash
gas logs
gas logs web
```

### gas rebuild

Deskripsi: mem-build ulang project memakai metadata build terakhir dari folder saat ini.

Usage:

```bash
gas rebuild
gas rebuild --git-pull no --yes
```

Options:

- `--git-pull yes|no`
- `--no-ui`
- `--yes`

Example:

```bash
gas rebuild --yes
gas rebuild --no-ui --git-pull no --yes
```

### gas remove

Deskripsi: menghapus app PM2 dan metadata build untuk folder project saat ini.

Usage:

```bash
gas remove
```

Options:

- `--no-ui`
- `--yes`

Example:

```bash
gas remove --yes
```

### gas doctor

Deskripsi: mengecek dependency environment build umum seperti Node, Go, PM2, dan SQLite.

Usage:

```bash
gas doctor
```

Options:

- `--no-ui`

Example:

```bash
gas doctor
```

### gas domain add

Deskripsi: legacy alias untuk deploy single-app berbasis domain. Command ini tetap ada untuk kompatibilitas, tetapi disarankan pindah ke `gas deploy`.

Usage:

```bash
gas domain add app.example.com --app web --ssl yes
```

Options:

- `--app <pm2-name>`
- `--port <port>`
- `--ssl yes|no`
- `--no-ui`
- `--yes`

Example:

```bash
gas domain add app.example.com --app web --ssl yes --yes
```

### gas domain remove

Deskripsi: legacy alias untuk `gas deploy remove`.

Usage:

```bash
gas domain remove app.example.com
```

Options:

- `--no-ui`
- `--yes`

Example:

```bash
gas domain remove app.example.com --yes
```

### gas domain list

Deskripsi: legacy alias untuk `gas deploy list`.

Usage:

```bash
gas domain list
```

Options:

- `--no-ui`

Example:

```bash
gas domain list
```

### gas help

Deskripsi: menampilkan panduan umum command dan opsi.

Usage:

```bash
gas help
gas build --help
gas deploy --help
```

Options:

- `--no-ui` untuk `gas help`
- `--help` atau `-h` di masing-masing command

Example:

```bash
gas help
gas deploy --help
gas rebuild --help
```

## Catatan Penggunaan

- `gas` tanpa argumen akan menampilkan overview command.
- Untuk automation, hampir semua workflow penting sebaiknya memakai `--no-ui` dan `--yes`.
- `gas deploy preview` adalah cara paling aman untuk mengecek hasil render config sebelum write ke Nginx.
- `gas rebuild` nyaman untuk operator server, tetapi di CI biasanya lebih baik memakai `gas build` dengan flag eksplisit.
- `gas domain` bukan planned feature baru, melainkan command legacy yang masih dipertahankan.

Untuk penjelasan alur build dan deploy yang lebih dalam, lanjutkan ke [GAS_BUILD_GUIDE.md](./GAS_BUILD_GUIDE.md) dan [GAS_DEPLOY_GUIDE.md](./GAS_DEPLOY_GUIDE.md).
