# GAS Installation Guide

## Tujuan

Panduan ini menjelaskan cara menyiapkan server untuk `gas-cli`, mulai dari dependency dasar sampai install, update, dan uninstall. Fokus utama project ini adalah Ubuntu atau VPS Linux yang menjalankan aplikasi dengan PM2 dan Nginx, jadi contoh command di bawah diasumsikan untuk Ubuntu.

## Requirement Server

Minimal requirement operasional untuk memakai `gas` dengan nyaman:

- Ubuntu dengan akses shell
- Bash 4 atau lebih baru
- akses `sudo` atau root untuk operasi instalasi dan deploy Nginx
- koneksi internet untuk install dependency, `git pull`, dan Certbot
- port 80 dan 443 terbuka bila akan memakai Nginx dan SSL publik

Kebutuhan runtime per use case:

- untuk build project Node/web: `node` dan `npm`
- untuk build project Go: `go`
- untuk run app: `pm2`
- untuk metadata global: `sqlite3`
- untuk deploy domain: `nginx`
- untuk SSL otomatis: `certbot` dan `python3-certbot-nginx`
- untuk HTTP verification: `curl`
- untuk UX interaktif yang lebih rapi: `gum` opsional

## Dependency Yang Dibutuhkan

Secara praktis, dependency bisa dibagi menjadi tiga kelompok.

### Core CLI

Dependency ini dibutuhkan hampir di semua server:

- `git`
- `sqlite3`
- `curl`
- `node`
- `npm`
- `pm2`

### Build Tambahan

Dependency ini tergantung project:

- `go` untuk project Go
- `pnpm` atau `yarn` bila project memakainya, karena `gas` akan mengikuti lockfile yang ada

### Deploy Tambahan

Dependency ini dibutuhkan bila server akan mengelola domain:

- `nginx`
- `certbot`
- `python3-certbot-nginx`
- `openssl`

## Contoh Instalasi Dependency di Ubuntu

### Paket dasar

```bash
sudo apt update
sudo apt install -y git sqlite3 curl nginx certbot python3-certbot-nginx openssl
```

### Node.js dan npm

Script `install.sh` project memakai NodeSource untuk Node 20. Jika ingin menyiapkan manual terlebih dahulu, pola yang sama bisa dipakai:

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

Verifikasi:

```bash
node -v
npm -v
```

### PM2

```bash
sudo npm install -g pm2
pm2 -v
```

### Go

Jika server juga membuild backend Go:

```bash
sudo apt install -y golang-go
go version
```

### gum (opsional)

`gum` tidak wajib. Tanpa `gum`, `gas` tetap berjalan dengan fallback plain terminal. Jika ingin UX interaktif yang lebih bersih:

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo tee /etc/apt/keyrings/charm.gpg >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | \
  sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update
sudo apt install -y gum
```

## Cara Install gas-cli

### Opsi 1: install lewat repository ini

Clone repo, lalu jalankan installer:

```bash
git clone <repo-gas-cli> /opt/gas-cli
cd /opt/gas-cli
chmod +x install.sh
./install.sh
```

Apa yang dilakukan `install.sh` saat ini:

- memastikan `git`, `sqlite3`, `curl`, `node`, `npm`, `pm2`, dan `gum` tersedia
- membuat symlink `bin/gas` ke `/usr/local/bin/gas`
- memberi permission execute ke `bin/gas`

Yang penting: `install.sh` tidak meng-install `nginx`, `certbot`, atau `go` secara otomatis. Untuk workflow deploy penuh, dependency itu tetap harus Anda siapkan sendiri.

### Opsi 2: symlink manual

Kalau Anda tidak ingin memakai installer:

```bash
chmod +x /opt/gas-cli/bin/gas
sudo ln -sf /opt/gas-cli/bin/gas /usr/local/bin/gas
```

Metode ini berguna bila dependency sudah dikelola lewat image, Ansible, atau provisioning lain.

## Verifikasi Instalasi

Setelah instalasi selesai, jalankan:

```bash
gas help
gas doctor
gas deploy doctor
```

Interpretasi cepat:

- `gas help` memastikan binary tersymlink dan entrypoint bisa dijalankan
- `gas doctor` mengecek dependency build umum
- `gas deploy doctor` mengecek readiness deploy Nginx dan SSL

## Lokasi Penting Setelah Install

Beberapa path yang perlu diketahui operator:

- binary global: `/usr/local/bin/gas`
- source repo: sesuai folder clone, misalnya `/opt/gas-cli`
- metadata global: `~/.config/gas/apps.db`
- file Nginx hasil deploy: `/etc/nginx/sites-available/<domain>`

## Cara Update

Update paling aman untuk install berbasis repository adalah:

```bash
cd /opt/gas-cli
git pull
./install.sh
gas help
```

Alasan menjalankan `install.sh` lagi:

- memastikan symlink tetap benar
- memastikan dependency yang mungkin baru ditambahkan tetap terpenuhi

Jika Anda mengelola symlink manual, update minimalnya:

```bash
cd /opt/gas-cli
git pull
chmod +x bin/gas
gas help
```

## Cara Uninstall

`gas-cli` tidak menyediakan uninstaller otomatis, jadi prosesnya manual dan harus disengaja. Langkah minimal untuk mencabut binary global:

```bash
sudo rm -f /usr/local/bin/gas
```

Jika repo ingin dihapus:

```bash
rm -rf /opt/gas-cli
```

Jika metadata tidak lagi dibutuhkan:

```bash
rm -f ~/.config/gas/apps.db
```

Perlu dicatat bahwa uninstall `gas` tidak otomatis:

- menghapus app PM2
- menghapus config Nginx
- mencabut sertifikat Certbot

Kalau server sebelumnya sudah dipakai operasional, bersihkan komponen itu secara terpisah dan hati-hati.

## Rekomendasi Praktis

Untuk server produksi, pola setup yang paling stabil biasanya seperti ini:

1. install dependency sistem terlebih dahulu
2. install `gas-cli`
3. jalankan `gas doctor` dan `gas deploy doctor`
4. build project pertama
5. baru lakukan deploy domain

Untuk CI runner, Anda tidak selalu perlu menginstall semua dependency deploy. Jika pipeline hanya melakukan SSH ke VPS dan menjalankan `gas` di server target, yang perlu lengkap justru server targetnya, bukan runner CI.

## Troubleshooting Singkat

Masalah yang paling sering muncul saat instalasi:

- `gas` tidak ditemukan
  Pastikan symlink `/usr/local/bin/gas` benar dan `bin/gas` executable.
- `sqlite3` tidak tersedia
  Metadata `info`, `list`, `rebuild`, dan deploy berbasis metadata akan terganggu.
- `pm2` tidak tersedia
  Build bisa gagal di tahap start atau restart process.
- `nginx` atau `certbot` tidak tersedia
  Build tetap bisa jalan, tetapi `gas deploy` atau SSL tidak akan bekerja.

Setelah setup dasar rapi, lanjutkan ke [GAS_COMMANDS.md](./GAS_COMMANDS.md) dan [GAS_BUILD_GUIDE.md](./GAS_BUILD_GUIDE.md).
