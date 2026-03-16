# PROJECT_STATUS.md

## Current Objective
- Menjaga `gas` stabil sebagai CLI build/deploy Ubuntu dengan PM2, Nginx, dan metadata SQLite.

## Current Phase
- Existing project
- Phase: stabilization and context normalization

## Summary Status
- [Observed] Repo aktif dan modular: build, deploy, info/list, restart/logs, rebuild/remove/doctor sudah ada di command/help.
- [Observed] Shared context selain `AGENTS.md` belum ada sebelum normalisasi ini.
- [Observed] `AGENTS.md` lama tertinggal dari surface repo saat ini, terutama area deploy dan command tambahan.
- [Observed] Paket dokumentasi operasional untuk command, install, build, deploy, CI/CD, dan arsitektur kini tersedia di `docs/`.
- [Observed] Portable agent context untuk repo pengguna `gas` kini tersedia di `AGENTS_GAS_CONTEXT.md`.

## Done
- [Observed] Thin entrypoint di `bin/gas` dengan dispatcher di `lib/commands.sh`.
- [Observed] Flow `gas build` sudah punya stack detection, PM2 strategy, runtime verify, dan metadata SQLite.
- [Observed] Flow `gas deploy` sudah ada beserta `preview`, `list`, `remove`, dan `doctor`.
- [Observed] Generator deploy SSL untuk mode `frontend-backend-split` kini mempertahankan reverse proxy di blok HTTPS untuk `certbot-nginx`, dengan redirect hanya di blok HTTP.
- [Observed] Deploy `frontend-backend-split` kini preserve path backend secara default, mendukung auto-detect backend base path best effort, dan menyediakan override eksplisit route/base-path/strip-prefix.
- [Observed] Build runtime verify kini mendukung `--health-path` dan fallback ke PM2 + port check saat path tidak diatur.
- [Observed] Smoke preview deploy tersedia di `scripts/smoke-deploy-preview.sh`.
- [Observed] Shared context distandardkan: `AGENTS.md`, `PROJECT_STATUS.md`, `TASKS.md`, `docs/decisions.md`, `docs/handoffs/HANDOFF_TEMPLATE.md`.
- [Observed] File `AGENTS_GAS_CONTEXT.md` ditambahkan sebagai konteks cepat portable untuk agent yang bekerja di repo pengguna `gas`.
- [Observed] Dokumentasi lengkap project ditambahkan di `docs/README.md`, `docs/GAS_INSTALLATION.md`, `docs/GAS_COMMANDS.md`, `docs/GAS_BUILD_GUIDE.md`, `docs/GAS_DEPLOY_GUIDE.md`, `docs/GAS_CICD_GUIDE.md`, dan `docs/GAS_ARCHITECTURE.md`.

## In Progress
- [Unknown] Tidak ada task implementasi aktif yang terdokumentasi di repo saat audit ini.

## Blockers / Risks
- [Observed] Status kerja tim sebelumnya tidak terdokumentasi; owner dan target rilis tidak diketahui.
- [Observed] Validasi runtime penuh butuh environment Ubuntu dengan PM2/Nginx/sqlite3; tidak bisa dibuktikan hanya dari repo.
- [Observed] README/help/AGENTS berpotensi drift lagi jika command surface berubah tanpa update konteks.

## Recently Touched Areas
- [Observed] `lib/build.sh`, `lib/commands.sh`, `README.md` terkait peningkatan handling build config node-web.
- [Observed] `lib/deploy.sh`, `lib/nginx.sh`, `lib/help.sh` terkait engine deploy, safety `nginx -t`, dan render SSL/certbot.
- [Observed] `lib/deploy.sh`, `lib/db.sh`, `lib/help.sh` terkait backend split routing, heuristik backend base path, dan help deploy.
- [Observed] `lib/pm2.sh`, `lib/db.sh`, `lib/ui.sh` terkait health check path build dan metadata terkait.
- [Observed] `lib/db.sh` menyimpan metadata build/deploy lintas project.
- [Observed] `docs/*.md` ditambah untuk dokumentasi penggunaan, operasi, dan arsitektur.

## Assumptions / Unknowns
- [Unknown] Prioritas produk setelah deploy wizard belum terdokumentasi formal.
- [Unknown] Coverage test selain smoke preview deploy belum terlihat di repo.
- [Assumption] `main` branch masih menjadi branch kerja utama karena HEAD ada di `main`.

## Next Recommended Steps
- Tetapkan 1-3 task aktif nyata di `TASKS.md` sebelum kerja fitur berikutnya.
- Saat command surface berubah, update `README.md`, `lib/help.sh`, dan file konteks dalam satu paket.
- Tambahkan validasi yang mudah diulang untuk command utama di luar `smoke-deploy-preview.sh`.
