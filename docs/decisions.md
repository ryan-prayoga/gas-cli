# decisions.md

## Entry 1
- Date: Unknown (pre-existing, observed 2026-03-16)
- Context: Repo CLI ini perlu tetap maintainable walau command bertambah.
- Decision: Pertahankan arsitektur Bash modular dengan entrypoint tipis di `bin/gas` dan dispatcher utama di `lib/commands.sh`.
- Rationale: Logic terpisah per domain lebih mudah diubah tanpa merusak command lain.
- Impact: Fitur baru sebaiknya masuk ke `lib/*.sh`, bukan menumpuk di entrypoint.
- Follow-up: Catat keputusan baru di file ini jika arsitektur berubah.

## Entry 2
- Date: Unknown (pre-existing, observed 2026-03-16)
- Context: Tool dipakai untuk interactive terminal dan automation/CI-CD.
- Decision: Interactive mode dan `--no-ui` adalah fitur setara; `gum` opsional dengan fallback plain terminal.
- Rationale: UX interaktif penting, tetapi automation tidak boleh bergantung pada TUI.
- Impact: Perubahan prompt/flow harus tetap punya jalur non-interaktif yang jelas dan kompatibel.
- Follow-up: Validasi parity flag/help saat menambah command atau prompt baru.

## Entry 3
- Date: Unknown (pre-existing, observed 2026-03-16)
- Context: Build/deploy lintas project butuh state global yang konsisten.
- Decision: Simpan metadata global di SQLite `~/.config/gas/apps.db` dengan migration ringan dan kompatibel.
- Rationale: Metadata perlu bisa dipakai lintas folder/project tanpa bergantung pada file lokal project.
- Impact: Perubahan schema harus backward compatible dan tercermin di command `info`, `list`, dan deploy-related flow.
- Follow-up: Dokumentasikan migration atau kolom baru saat schema berubah.
