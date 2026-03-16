# TASKS.md

## Todo
- ID: T-001
  Title: Re-validate help/README/context parity after deploy expansion
  Priority: P1
  Owner/Agent: Unassigned
  Dependencies: `README.md`, `lib/help.sh`, command surface review
  Notes: `AGENTS.md` lama tertinggal dari kondisi repo; jaga parity setelah perubahan berikutnya.
- ID: T-002
  Title: Verify `gas info` and `gas list` output against current metadata quality
  Priority: P2
  Owner/Agent: Unassigned
  Dependencies: sample metadata in `~/.config/gas/apps.db`
  Notes: Ini prioritas lama yang masih relevan dari arahan repo.
- ID: T-003
  Title: Add repeatable smoke checks for core commands beyond deploy preview
  Priority: P2
  Owner/Agent: Unassigned
  Dependencies: decision on test scope
  Notes: Saat ini yang terlihat hanya `scripts/smoke-deploy-preview.sh`.

## Doing
- None recorded.

## Blocked
- None recorded.

## Done
- ID: T-000
  Title: Normalize shared project context files
  Priority: P1
  Owner/Agent: Codex
  Dependencies: repo audit
  Notes: Menstandarkan `AGENTS.md`, `PROJECT_STATUS.md`, `TASKS.md`, `docs/decisions.md`, dan template handoff.
- ID: T-004
  Title: Create full documentation set for gas-cli
  Priority: P1
  Owner/Agent: Codex
  Dependencies: repo scan, command surface audit, docs authoring
  Notes: Menambahkan dokumentasi install, command reference, build guide, deploy guide, CI/CD guide, dan architecture guide di `docs/`.
- ID: T-005
  Title: Fix certbot split deploy HTTPS proxy generation
  Priority: P1
  Owner/Agent: Codex
  Dependencies: `lib/deploy.sh`, smoke preview deploy, build runtime verify
  Notes: Memastikan `certbot-nginx` untuk `frontend-backend-split` tetap menghasilkan blok HTTPS dengan reverse proxy, menambah guard `nginx -t` sebelum reload, dan menambah `gas build --health-path`.
