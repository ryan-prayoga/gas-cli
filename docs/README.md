# gas-cli Documentation

## Overview

`gas-cli` adalah CLI Bash untuk membantu build, run, dan deploy aplikasi ke Ubuntu atau VPS dengan alur yang konsisten. Fokus utamanya adalah dua pekerjaan yang biasanya repetitif dan rawan drift:

- menjalankan aplikasi Go atau Node/web lewat PM2
- mengelola konfigurasi Nginx dan metadata deployment secara terstruktur

Tool ini dibuat untuk mengurangi setup manual per project. Daripada tiap repo punya skrip deploy berbeda, `gas` mencoba menyediakan surface command yang seragam: deteksi stack, build, start atau restart PM2, verifikasi runtime, lalu menyimpan hasilnya ke database metadata global. Dari metadata itu, flow deploy bisa memilih app yang sudah pernah dibuild dan menghasilkan konfigurasi Nginx yang lebih konsisten.

## Apa Itu gas CLI

Secara praktis, `gas` adalah DevOps helper untuk server Linux, terutama Ubuntu, yang berjalan di atas beberapa komponen inti:

- Bash sebagai runtime utama CLI
- PM2 untuk process manager
- SQLite untuk metadata global
- Nginx untuk web serving dan reverse proxy
- Certbot untuk otomatisasi SSL ketika dibutuhkan

`gas` mendukung dua gaya penggunaan yang setara:

- mode interaktif, dengan prompt terminal dan dukungan `gum` bila tersedia
- mode automation atau CI/CD, memakai flag seperti `--no-ui` dan `--yes`

Ini penting karena kebutuhan operator lokal dan pipeline otomatis biasanya berbeda, tetapi tidak boleh menghasilkan perilaku yang berbeda jauh.

## Masalah yang Diselesaikan

Project ini menyasar beberapa pain point yang umum di VPS deployment:

- Build project sering bergantung pada tebakan manual: ini Go, SvelteKit, Next.js, atau Node biasa.
- PM2 config sering tercecer per project dan tidak punya metadata terpusat.
- Deploy Nginx rawan salah ketik, tidak konsisten antar domain, dan susah direview.
- Automation mode sering rusak karena tool terlalu fokus pada prompt interaktif.
- Dokumentasi internal mudah drift ketika command bertambah tetapi help text dan workflow tidak ikut diperbarui.

`gas` mencoba merapikan semua itu dengan satu alur:

1. deteksi stack project dari folder kerja
2. pilih atau hitung strategy build dan run
3. jalankan aplikasi lewat PM2
4. verifikasi runtime
5. simpan metadata ke `~/.config/gas/apps.db`
6. gunakan metadata itu untuk deploy domain dengan Nginx

## Fitur Utama

- Build project Go dan Node/web ecosystem dengan satu command.
- Auto-detect stack untuk Go, SvelteKit, Next.js, Nuxt, Vite, Node generic, mixed, dan unknown.
- Deteksi ecosystem config PM2 seperti `ecosystem.config.cjs` atau `pm2.config.js`.
- Strategy run yang fleksibel: `auto`, `ecosystem`, `node-entry`, `npm-preview`, dan `npm-start`.
- Runtime verification setelah build, mencakup status PM2, port listen, dan HTTP localhost bila `curl` tersedia.
- Metadata global SQLite yang bisa dipakai lintas project.
- Deploy wizard Nginx dengan beberapa mode routing.
- Preview config Nginx tanpa apply.
- Legacy alias `gas domain` untuk kompatibilitas, tetapi diarahkan ke engine deploy baru.

## Dokumentasi Yang Tersedia

Dokumen di folder ini dibagi berdasarkan kebutuhan pengguna dan maintainer:

- [GAS_INSTALLATION.md](./GAS_INSTALLATION.md)
  Menjelaskan requirement server, dependency, instalasi, update, dan uninstall.
- [GAS_COMMANDS.md](./GAS_COMMANDS.md)
  Referensi semua command dan subcommand CLI yang tersedia di codebase saat ini.
- [GAS_BUILD_GUIDE.md](./GAS_BUILD_GUIDE.md)
  Menjelaskan workflow `gas build`, stack detection, strategy build, dan contoh nyata.
- [GAS_DEPLOY_GUIDE.md](./GAS_DEPLOY_GUIDE.md)
  Menjelaskan workflow `gas deploy`, mode routing, domain setup, dan SSL.
- [GAS_CICD_GUIDE.md](./GAS_CICD_GUIDE.md)
  Panduan memakai `gas` di automation dan CI/CD, termasuk contoh GitHub Actions.
- [GAS_ARCHITECTURE.md](./GAS_ARCHITECTURE.md)
  Penjelasan internal tool: modul Bash, metadata SQLite, PM2, Nginx, dan flow runtime.

## Siapa Yang Perlu Membaca Apa

Jika Anda baru pertama kali menyentuh project ini, urutan baca yang paling efisien biasanya:

1. dokumen ini untuk memahami ruang lingkup tool
2. `GAS_INSTALLATION.md` untuk menyiapkan server
3. `GAS_COMMANDS.md` untuk melihat command surface yang tersedia
4. `GAS_BUILD_GUIDE.md` dan `GAS_DEPLOY_GUIDE.md` untuk workflow sehari-hari
5. `GAS_ARCHITECTURE.md` bila Anda akan mengembangkan atau mengubah codebase

Jika tujuan Anda adalah automation, baca `GAS_CICD_GUIDE.md` lebih awal karena mode non-interaktif punya beberapa kebiasaan penting, misalnya penggunaan `--no-ui`, `--yes`, dan pemilihan flag eksplisit agar pipeline lebih stabil.

## Ringkasan Workflow Harian

Untuk penggunaan paling umum di server:

```bash
gas doctor
gas build
gas info
gas deploy
```

Dalam mode non-interaktif, alurnya biasanya berubah menjadi:

```bash
gas build --no-ui --type node-web --pm2-name app --port 4001 --strategy auto --yes
gas deploy --no-ui --app app --domain app.example.com --mode single-app --ssl certbot-nginx --yes
```

Perlu dicatat bahwa `gas build` sudah melakukan start atau restart aplikasi lewat PM2. Jadi pada banyak kasus, pipeline tidak perlu memanggil `pm2 restart` terpisah kecuali ada kebutuhan operasional khusus di luar flow bawaan `gas`.

## Batasan Saat Ini

Dokumentasi ini hanya menjelaskan command yang memang ada di codebase saat ini. Beberapa hal penting yang perlu diketahui:

- Deploy server yang didukung saat ini adalah `nginx`.
- Opsi `apache` sudah muncul di prompt sebagai arah masa depan, tetapi belum didukung. Ini bukan command aktif.
- `gas domain` masih tersedia, tetapi statusnya legacy alias.
- Validasi runtime penuh tetap bergantung pada environment server nyata. Dokumentasi ini tidak mengklaim semua flow bisa diverifikasi hanya dari repository.

## Prinsip Penggunaan

Agar pengalaman memakai `gas` stabil, ada beberapa prinsip praktis:

- Untuk build, utamakan command eksplisit di CI dibanding mengandalkan prompt.
- Untuk deploy, jadikan `gas deploy preview` sebagai langkah review sebelum write.
- Untuk perubahan domain, pastikan DNS sudah resolve sebelum memilih `certbot-nginx`.
- Untuk maintenance jangka panjang, anggap `apps.db` sebagai sumber metadata operasional, bukan source of truth aplikasi.

Dokumen berikutnya menjabarkan tiap area ini secara lebih detail.
