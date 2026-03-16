# GAS CI/CD Guide

## Tujuan

Dokumen ini menjelaskan cara memakai `gas-cli` dalam workflow automation dan CI/CD. Fokus utamanya adalah penggunaan non-interaktif yang stabil, dapat diulang, dan tidak bergantung pada prompt terminal.

## Prinsip Dasar

`gas` punya dua mode pemakaian:

- interaktif untuk operator manusia
- non-interaktif untuk pipeline

Untuk CI/CD, gunakan selalu:

- `--no-ui`
- `--yes`
- flag eksplisit seperti `--type`, `--pm2-name`, `--port`, dan `--strategy`

Jangan mengandalkan prompt default di pipeline. Pipeline harus bisa dibaca sebagai deklarasi build yang jelas.

## Workflow CI/CD Yang Disarankan

Alur umum yang sesuai dengan desain tool ini adalah:

```text
git push
-> CI/CD trigger
-> SSH ke server
-> git pull
-> gas build
-> runtime verification
-> optional gas deploy / nginx reload
```

Anda sempat menyebut pola:

```text
git push -> CI/CD trigger -> SSH server -> gas build -> pm2 restart
```

Secara implementasi aktual, `gas build` sudah melakukan start atau restart PM2. Jadi langkah `pm2 restart` terpisah biasanya redundant. Jika app berhasil dibuild dan diverifikasi, PM2 sudah berada pada state terbaru. Tambahkan `pm2 restart` manual hanya jika ada kebutuhan operasional di luar flow `gas`, misalnya reload service lain yang tidak dikelola metadata build.

## Prasyarat di Server Target

Sebelum CI bisa mengandalkan `gas`, server target harus sudah siap:

- repository aplikasi sudah ada di server
- `gas-cli` sudah terinstall
- dependency sistem sudah tersedia
- app pernah diuji manual minimal sekali
- key SSH dari CI sudah diizinkan

Ini penting karena runner CI biasanya hanya menjadi pengirim command. Runtime sebenarnya tetap terjadi di VPS.

## Build Otomatis

Contoh build untuk frontend Node/web:

```bash
gas build --no-ui --type node-web --pm2-name app --port 4001 --strategy auto --git-pull no --yes
```

Contoh build untuk backend Go:

```bash
gas build --no-ui --type go --pm2-name api --port 4000 --git-pull no --yes
```

Mengapa `--git-pull no` sering lebih baik di CI:

- CI biasanya sudah melakukan checkout atau `git pull` sendiri
- pemisahan tahap fetch source dan tahap build membuat log lebih bersih
- lebih mudah membedakan kegagalan network Git dari kegagalan build

## Kapan Memakai gas rebuild

`gas rebuild` ada, tetapi lebih cocok untuk operator server dibanding pipeline utama. Alasannya:

- command ini bergantung pada metadata build lama
- pipeline biasanya lebih aman bila menyatakan konfigurasi secara eksplisit

Gunakan `gas rebuild` hanya jika Anda sengaja membangun workflow yang memang memanfaatkan metadata server sebagai sumber parameter build.

## Deploy Domain di Pipeline

Ada dua pola umum:

### Pola 1: deploy domain sekali, lalu pipeline hanya build

Ini pola paling stabil untuk banyak aplikasi:

1. operator menjalankan `gas deploy` sekali saat setup awal
2. pipeline berikutnya hanya melakukan `git pull` dan `gas build`

Kelebihannya:

- risiko perubahan Nginx saat deploy rutin jadi nol
- sertifikat dan domain tidak disentuh pada tiap release

### Pola 2: build dan deploy config lewat pipeline

Pakai ini bila routing memang berubah otomatis, misalnya environment ephemeral atau config reverse proxy ikut berubah.

Contoh:

```bash
gas deploy --no-ui --app app --domain app.example.com --mode single-app --ssl certbot-nginx --reuse-existing yes --yes
```

Dalam pola ini, biasakan memakai `--reuse-existing yes` dan, bila perlu, jadikan `gas deploy preview` sebagai langkah review di job terpisah.

## Contoh GitHub Actions

Berikut contoh workflow sesuai permintaan untuk deploy ke VPS via SSH:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.SSH_KEY }}
          script: |
            cd /home/ubuntu/projects/app
            git pull
            gas build --no-ui --type svelte --pm2-name app --port 4001 --yes
```

Catatan akurasi: di codebase saat ini, `--type svelte` akan dinormalisasi menjadi `node-web`. Jadi contoh di atas valid, tetapi bentuk yang lebih eksplisit dan lebih jelas untuk maintainer adalah:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.SSH_KEY }}
          script: |
            cd /home/ubuntu/projects/app
            git pull
            gas build --no-ui --type node-web --pm2-name app --port 4001 --strategy auto --git-pull no --yes
```

## Contoh Dengan Backend Go

Jika repository di server adalah backend Go:

```yaml
script: |
  cd /home/ubuntu/projects/api
  git pull
  gas build --no-ui --type go --pm2-name api --port 4000 --git-pull no --yes
```

## Contoh Dengan Frontend dan Backend Terpisah

Jika ada dua repository atau dua folder berbeda:

```bash
cd /home/ubuntu/projects/frontend
git pull
gas build --no-ui --type node-web --pm2-name web --port 4001 --strategy auto --git-pull no --yes

cd /home/ubuntu/projects/backend
git pull
gas build --no-ui --type go --pm2-name api --port 4000 --git-pull no --yes
```

Domain biasanya cukup di-setup sekali dengan:

```bash
gas deploy --no-ui --frontend web --backend api --domain app.example.com --mode frontend-backend-split --yes
```

## Review dan Preview Config

Untuk workflow yang sensitif terhadap perubahan Nginx, Anda bisa menambahkan job preview:

```bash
gas deploy preview --no-ui --app app --domain app.example.com --mode single-app --save-preview temp --yes
```

Ini berguna bila Anda ingin memeriksa hasil config di log CI sebelum memutuskan apply dari job lain.

## Secrets dan Security

Minimal secrets yang biasanya dibutuhkan di GitHub Actions:

- `VPS_HOST`
- `VPS_USER`
- `SSH_KEY`

Praktik yang direkomendasikan:

- gunakan deploy key atau key khusus CI, bukan key pribadi operator
- batasi user SSH ke direktori dan privilege yang memang diperlukan
- jika pipeline juga akan mengubah Nginx, pastikan user target punya `sudo` yang sesuai

## Failure Mode Yang Umum

Masalah CI/CD yang paling sering:

- `gas` belum terinstall di server target
- `pm2` atau `sqlite3` tidak ada
- metadata belum pernah dibuat karena app belum pernah dibuild
- domain belum resolve sehingga Certbot gagal
- pipeline memakai prompt implicit karena lupa `--no-ui`

Karena itu, langkah audit yang berguna sebelum otomatisasi penuh adalah:

```bash
gas doctor
gas deploy doctor
gas list
```

## Kesimpulan Praktis

Untuk sebagian besar tim, pola paling sehat adalah:

1. setup server dan domain sekali secara manual
2. jadikan `gas build --no-ui ... --yes` sebagai inti deploy harian
3. pakai `gas deploy` lagi hanya ketika konfigurasi Nginx atau domain berubah

Jika Anda perlu memahami alasan teknis di balik perilaku ini, lanjutkan ke [GAS_ARCHITECTURE.md](./GAS_ARCHITECTURE.md).
