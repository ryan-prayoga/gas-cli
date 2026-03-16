# GAS Build Guide

## Gambaran Umum

`gas build` adalah pusat workflow project ini. Command ini tidak hanya menjalankan proses build, tetapi juga:

- mendeteksi jenis stack dari folder kerja
- memilih strategy run yang paling cocok
- menyalakan atau mengganti process PM2
- memverifikasi runtime
- menyimpan metadata build ke database global

Dengan kata lain, `gas build` adalah jembatan antara source code project dan state operasional server.

## Bagaimana gas Mendeteksi Stack

Deteksi stack dilakukan dari current directory. Implementasi saat ini memakai sinyal berikut:

- Go bila ada `go.mod`, `main.go`, atau `cmd/*/main.go`
- SvelteKit bila `package.json` mengandung `@sveltejs/kit`
- Next.js bila `package.json` mengandung `next`
- Nuxt bila `package.json` mengandung `nuxt`
- Vite bila `package.json` mengandung `vite`
- Node generic bila ada `package.json` tanpa framework spesifik
- Mixed bila sinyal Go dan Node muncul bersamaan
- Unknown bila tidak ada sinyal yang cukup kuat

Hasil deteksi ditampilkan lebih dulu ke user. Dalam mode interaktif, ini mempengaruhi default pilihan. Dalam mode non-interaktif, nilai itu bisa dipakai langsung atau Anda override lewat `--type`.

Contoh aman untuk automation:

```bash
gas build --no-ui --type node-web --pm2-name web --port 4001 --yes
```

## Langkah Besar Workflow Build

Secara umum, flow `gas build` adalah:

1. parse argumen
2. aktifkan mode UI atau plain terminal
3. coba baca konfigurasi build terakhir dari metadata
4. deteksi stack
5. deteksi ecosystem config bila ada
6. kumpulkan pilihan build: type, strategy, PM2 name, port, dependency mode
7. tampilkan summary
8. optional `git pull`
9. build dan start lewat PM2
10. verifikasi runtime
11. simpan metadata ke `~/.config/gas/apps.db`

Jika metadata lama ditemukan, `gas` bisa menawarkan reuse konfigurasi itu, terutama saat operator mengulang deploy dari folder yang sama.

## Dependency Install Strategy

`gas` punya mode dependency install berikut:

- `auto`
- `yes`
- `no`

Mode `auto` adalah default. Perilakunya berbeda tergantung stack:

- untuk Node, install dijalankan bila `node_modules` belum ada atau file lock berubah setelah `git pull`
- untuk Go, `go mod tidy` dijalankan bila `go.mod` atau `go.sum` berubah

Untuk project Node, package manager dideteksi dari lockfile:

- `pnpm-lock.yaml` -> `pnpm install`
- `yarn.lock` -> `yarn install`
- `package-lock.json` atau `npm-shrinkwrap.json` -> `npm install`

## Ecosystem Mode

Sebelum memilih strategy, `gas` akan mencari file PM2 ecosystem dengan urutan:

- `ecosystem.config.cjs`
- `ecosystem.config.js`
- `pm2.config.cjs`
- `pm2.config.js`

Jika file ditemukan, `gas` mencoba membaca default seperti:

- `name`
- `script`
- `args`
- `cwd`
- `PORT`

Strategy `ecosystem` punya dua varian praktis:

- reuse ecosystem yang sudah ada
- generate `ecosystem.config.cjs` baru bila file yang ada tidak dipakai

Ini cocok ketika project memang sudah punya file PM2 yang ingin dipertahankan sebagai sumber konfigurasi runtime.

Contoh:

```bash
gas build --no-ui --type node-web --pm2-name web --port 4001 --strategy ecosystem --reuse-ecosystem yes --yes
```

## Node-Entry Mode

Strategy `node-entry` dipakai ketika aplikasi menghasilkan file entry server yang bisa dijalankan langsung lewat `node`. `gas` mencari kandidat file seperti:

- `build/index.js`
- `.svelte-kit/output/server/index.js`
- `.output/server/index.mjs`
- `dist/server/entry.mjs`
- `server/index.js`
- `dist/index.js`

Kalau salah satu ditemukan, PM2 akan menjalankan:

```bash
pm2 start node --name <pm2-name> --cwd <project> -- <entry-file>
```

Mode ini sering cocok untuk aplikasi yang menghasilkan server build eksplisit, terutama SvelteKit adapter-node atau beberapa output SSR lain.

## npm preview

Strategy `npm-preview` memakai script:

```bash
npm run preview -- --host 0.0.0.0 --port <port>
```

Mode ini berguna ketika project web menyediakan preview server tetapi tidak punya start script server production yang lebih tepat. Untuk beberapa tool berbasis Vite, ini menjadi fallback yang masuk akal.

Kelemahannya jelas: `preview` kadang lebih dekat ke mode demo daripada runtime production. Karena itu, dalam auto mode `gas` tidak langsung memilih ini bila masih ada opsi yang lebih kuat.

## npm start

Strategy `npm-start` dijalankan jika `package.json` memiliki script `start`.

PM2 akan menjalankan:

```bash
pm2 start npm --name <pm2-name> --cwd <project> -- run start
```

Ini cocok untuk Node API, Express app, Next.js custom server, atau project lain yang memang mendefinisikan `start` sebagai entry runtime produksi.

## Auto Mode

`auto` adalah default yang paling penting untuk dipahami. Urutan fallback implementasinya saat ini adalah:

1. `ecosystem` bila ada ecosystem config valid
2. `npm-start` bila ada script `start`
3. `node-entry` bila entry file hasil build terdeteksi
4. `npm-preview` sebagai fallback terakhir

Setelah tiap kandidat dijalankan, `gas` memverifikasi runtime. Strategy yang lolos verifikasi dipilih sebagai hasil final. Jika semuanya gagal, build dihentikan dengan error yang merangkum kegagalan tiap strategy.

## Build Project Go

Untuk project Go, flow-nya berbeda dari Node:

- target build dicari dari `main.go` atau `cmd/*/main.go`
- output binary diletakkan di `.gas/bin/<pm2-name>`
- file `.env` atau `.env.production` bisa diupdate untuk `PORT`
- PM2 menjalankan binary langsung

Contoh backend Go:

```bash
gas build
gas build --no-ui --type go --pm2-name api --port 4000 --yes
```

Jika project punya beberapa target di `cmd/*`, mode interaktif akan meminta pilihan target. Dalam mode non-interaktif, target pertama dipilih otomatis, jadi untuk repo multi-binary sebaiknya operator memverifikasi struktur project terlebih dahulu.

## Build SvelteKit Frontend

SvelteKit biasanya akan terdeteksi sebagai stack Node-based. Pilihan strategy yang paling umum:

- `ecosystem` bila repo sudah punya config PM2
- `node-entry` bila output server bisa ditemukan
- `npm-preview` bila hanya ada preview server

Contoh:

```bash
gas build --no-ui --type node-web --pm2-name web --port 4001 --strategy auto --yes
```

Jika Anda tahu repo memakai ecosystem config yang stabil:

```bash
gas build --no-ui --type node-web --pm2-name web --port 4001 --strategy ecosystem --reuse-ecosystem yes --yes
```

## Build Node API

Untuk API Node biasa, strategy yang sering paling tepat adalah `npm-start` atau `ecosystem`.

Contoh:

```bash
gas build --no-ui --type node-web --pm2-name api --port 3000 --strategy npm-start --yes
```

Kalau repo punya file ecosystem:

```bash
gas build --no-ui --type node-web --pm2-name api --port 3000 --strategy ecosystem --reuse-ecosystem yes --yes
```

## Runtime Verification

Sesudah PM2 start atau restart, `gas` melakukan verifikasi bertahap:

- cek status PM2
- cek port listen
- cek HTTP `http://127.0.0.1:<port>` bila `curl` tersedia

Interpretasinya:

- sukses penuh bila PM2 online, port listen, dan HTTP OK
- warning bila PM2 online dan port listen, tetapi HTTP belum merespons
- gagal bila status PM2 atau port tidak sesuai

Verifikasi ini penting karena build yang sukses belum tentu berarti aplikasi benar-benar siap menerima trafik.

## Metadata Setelah Build

Jika build selesai, metadata disimpan ke `~/.config/gas/apps.db`. Beberapa field penting:

- `project_dir`
- `app_type`
- `port`
- `pm2_name`
- `env_file`
- `start_file`
- `run_mode`
- `node_version`
- `npm_version`
- `go_version`
- `svelte_strategy`
- `deps_mode`
- `verify_status`
- `verify_message`

Metadata ini dipakai ulang oleh command seperti `gas info`, `gas list`, `gas rebuild`, dan `gas deploy`.

## Praktik Yang Direkomendasikan

- Gunakan `--type`, `--pm2-name`, dan `--port` secara eksplisit di CI.
- Pakai `--strategy auto` kecuali Anda tahu betul runtime yang diinginkan.
- Untuk project yang sudah punya ecosystem config bagus, gunakan `--reuse-ecosystem yes`.
- Jalankan `gas info` setelah build pertama untuk memastikan metadata yang tersimpan memang sesuai.

Kalau build sudah stabil, tahap berikutnya biasanya adalah menghubungkan app ke domain lewat [GAS_DEPLOY_GUIDE.md](./GAS_DEPLOY_GUIDE.md).
