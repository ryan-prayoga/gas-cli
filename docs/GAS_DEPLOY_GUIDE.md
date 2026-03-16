# GAS Deploy Guide

## Gambaran Umum

`gas deploy` adalah engine deploy Nginx di project ini. Ia bekerja di atas metadata build yang disimpan oleh `gas build`, lalu membantu operator memilih app, domain, mode routing, SSL, preview, test, reload, dan verifikasi.

Flow dasarnya sederhana:

1. pilih app dari metadata `apps.db`
2. tentukan domain dan alias
3. pilih mode deploy
4. generate konfigurasi Nginx
5. preview bila diperlukan
6. tulis file ke `sites-available`
7. enable site, test, reload, dan simpan metadata deployment

## Prasyarat Sebelum Deploy

Sebelum menjalankan `gas deploy`, sebaiknya pastikan:

- app sudah pernah dijalankan lewat `gas build`
- `nginx` tersedia
- `sqlite3` tersedia
- user memiliki root atau `sudo`
- DNS domain sudah diarahkan ke server bila akan memakai `certbot-nginx`

Command pengecekan cepat:

```bash
gas deploy doctor
gas list
```

## Cara Menggunakan gas deploy

Mode interaktif:

```bash
gas deploy
```

Mode automation:

```bash
gas deploy --no-ui --app web --domain app.example.com --mode single-app --ssl certbot-nginx --yes
```

Subcommand yang tersedia:

- `gas deploy` atau `gas deploy add`
- `gas deploy preview`
- `gas deploy list`
- `gas deploy remove`
- `gas deploy doctor`

## Bagaimana gas Memilih App

App yang bisa dipilih berasal dari tabel `apps` di `~/.config/gas/apps.db`. Artinya, `gas deploy` tidak mencari proses PM2 secara liar, tetapi memakai daftar app yang sebelumnya dibuild oleh `gas`.

Untuk mode interaktif, daftar kandidat disusun dengan prioritas:

- project di folder saat ini
- project lain yang pernah disimpan

Pendekatan ini membuat deploy lebih konsisten, karena informasi seperti `pm2_name`, `project_dir`, dan `port` sudah punya jejak metadata.

## Mode Deploy Yang Didukung

### single-app

Semua request `/` diproxy ke satu app atau upstream. Ini mode paling sederhana dan paling umum untuk:

- aplikasi SSR tunggal
- panel admin
- API tunggal

Contoh:

```bash
gas deploy --no-ui --app web --domain app.example.com --mode single-app --ssl certbot-nginx --yes
```

### frontend-backend-split

Mode ini membuat split routing bawaan:

- `/` ke frontend
- `/api/` ke backend
- default preserve full request path ke upstream backend

Best effort auto-detect akan mencoba membaca:

- metadata app `gas` seperti `health_path` bila ada
- file environment backend untuk key seperti `API_BASE_PATH`, `BASE_PATH`, `APP_BASE_PATH`, `ROUTE_PREFIX`, `PUBLIC_API_PREFIX`
- source code backend untuk pola prefix router seperti `Group("/api")`, `Group("/api/v1")`, atau `app.Group("/v1")`

Flag eksplisit yang tersedia:

- `--backend-route <path>` untuk route publik di Nginx, contoh `/api/`
- `--backend-base-path <path>` untuk base path yang diharapkan backend, contoh `/api` atau `/api/v1`
- `--backend-strip-prefix yes|no` untuk menghapus prefix route publik sebelum diteruskan ke upstream. Default: `no`

Opsional, Anda juga bisa menambahkan static alias `/uploads/` lewat `--uploads`.

Contoh:

```bash
gas deploy --no-ui \
  --frontend web \
  --backend api \
  --domain app.example.com \
  --mode frontend-backend-split \
  --uploads /home/ubuntu/app/uploads \
  --ssl certbot-nginx \
  --yes
```

Contoh explicit strip-prefix:

```bash
gas deploy --no-ui \
  --frontend web \
  --backend api \
  --domain app.example.com \
  --mode frontend-backend-split \
  --backend-route /api/ \
  --backend-base-path / \
  --backend-strip-prefix yes \
  --yes
```

### custom-multi-location

Ini adalah mode untuk custom routes. Anda mendefinisikan location satu per satu memakai `--location`, misalnya:

```bash
gas deploy preview --no-ui \
  --mode custom-multi-location \
  --domain app.example.com \
  --location '/=proxy:web' \
  --location '/api/=proxy:api' \
  --location '/uploads/=alias:/srv/uploads' \
  --yes
```

Tipe location yang didukung:

- `proxy:<pm2-name>`
- `proxy:<host:port>`
- `alias:<dir>`
- `root:<dir>`
- `redirect:<url>`
- `return:<code>:<text>`

### static-only

Mode ini melayani file statis dari sebuah root directory. Ini cocok untuk site statis murni.

```bash
gas deploy --no-ui --domain static.example.com --mode static-only --static-root /var/www/site --yes
```

### redirect-only

Mode ini membuat domain yang hanya berfungsi sebagai redirect.

```bash
gas deploy --no-ui --domain old.example.com --mode redirect-only --redirect-target https://new.example.com --yes
```

### maintenance

Mode ini menampilkan halaman maintenance. `gas` bisa memakai directory yang Anda sediakan, atau membuat halaman maintenance default.

```bash
gas deploy --no-ui --domain app.example.com --mode maintenance --generate-maintenance yes --yes
```

## Static Alias dan Custom Routes

Permintaan seperti "static alias" dan "custom routes" di project ini bukan command terpisah, tetapi bagian dari mode deploy:

- static alias umumnya diwujudkan dengan `--uploads` pada mode `frontend-backend-split`, atau `--location '/uploads/=alias:/path'` pada `custom-multi-location`
- custom routes diwujudkan lewat `--location`

Jadi jika Anda mencari mode khusus bernama `static alias`, itu bukan command yang berdiri sendiri. Implementasinya ada di sistem `location` Nginx hasil render `gas deploy`.

## Bagaimana gas Generate Nginx Config

Engine deploy merender file konfigurasi berdasarkan:

- domain utama dan alias
- mode deploy
- daftar route atau location
- preset websocket, timeout, gzip, security headers, dan cache
- pilihan SSL

Header proxy bawaan mencakup:

- `Host`
- `X-Real-IP`
- `X-Forwarded-For`
- `X-Forwarded-Proto`
- `Upgrade` dan `Connection` bila websocket aktif

## Contoh Konfigurasi Nginx Yang Dihasilkan

Contoh untuk mode `frontend-backend-split` dengan alias `/uploads/` secara konseptual akan mirip seperti ini:

```nginx
# managed by gas
server {
    listen 80;
    listen [::]:80;
    server_name app.example.com;
    gzip on;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    location / {
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_pass http://127.0.0.1:4001;
    }

    location /api/ {
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_pass http://127.0.0.1:4000;
    }

    location /uploads/ {
        alias /home/ubuntu/app/uploads;
        expires 1h;
        add_header Cache-Control "public, max-age=3600";
        try_files $uri $uri/ =404;
    }
}
```

Jika `--backend-strip-prefix yes` dipakai, `gas` akan merender rewrite secara eksplisit sebelum proxy, misalnya:

```nginx
location /api/ {
    rewrite ^/api/?(.*)$ /$1 break;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_pass http://127.0.0.1:4000;
}
```

Untuk `--ssl existing-certificate`, `gas` juga merender block HTTPS dengan `ssl_certificate` dan `ssl_certificate_key`. Untuk `--ssl certbot-nginx`, preview awal tetap berbentuk HTTP, lalu Certbot akan menambahkan atau mengubah block HTTPS setelah issue sertifikat berhasil.

## Setup Domain

Argumen domain penting yang didukung:

- `--domain` untuk domain utama
- `--alias-domain` untuk alias tambahan
- `--www yes|no` untuk alias `www`
- `--canonical apex|www|none|custom`
- `--canonical-host` bila memakai canonical custom

Contoh:

```bash
gas deploy --no-ui \
  --app web \
  --domain example.com \
  --www yes \
  --canonical apex \
  --mode single-app \
  --ssl certbot-nginx \
  --yes
```

Dengan konfigurasi itu, host alternatif akan diarahkan ke host utama sesuai aturan canonical.

## Setup SSL Dengan Certbot

Mode SSL yang tersedia:

- `none`
- `certbot-nginx`
- `existing-certificate`

Untuk SSL otomatis:

```bash
gas deploy --no-ui --app web --domain app.example.com --mode single-app --ssl certbot-nginx --yes
```

Hal yang perlu dipenuhi:

- domain harus resolve ke server
- port 80 dan 443 bisa diakses dari internet
- `certbot` dan `python3-certbot-nginx` terpasang

`gas` akan memberi warning bila domain belum resolve dari server saat mode `certbot-nginx` dipilih.

## Setup SSL Dengan Sertifikat Existing

Jika sertifikat sudah dikelola di luar `gas`, misalnya oleh ACME internal atau provisioner lain:

```bash
gas deploy --no-ui \
  --app web \
  --domain app.example.com \
  --mode single-app \
  --ssl existing-certificate \
  --ssl-cert /etc/letsencrypt/live/app.example.com/fullchain.pem \
  --ssl-key /etc/letsencrypt/live/app.example.com/privkey.pem \
  --yes
```

## Preview, Test, Reload, dan Verification

Salah satu kekuatan `gas deploy` adalah kontrol bertahap:

- `--preview` untuk menampilkan config dulu
- `--dry-run` untuk memastikan tidak ada write
- `--test yes|no` untuk `nginx -t`
- `--reload yes|no` untuk reload service
- `--verify yes|no` untuk cek upstream dan domain

Contoh review tanpa apply:

```bash
gas deploy preview --no-ui --app web --domain app.example.com --mode single-app
```

## Metadata Deployment

Sesudah deploy berhasil, `gas` menyimpan data ke tabel:

- `deployments`
- `domains` untuk kompatibilitas lama

Field penting meliputi:

- domain
- project directory
- PM2 name
- port
- deploy mode
- SSL mode
- alias domains
- app map
- nginx config path

Metadata ini dipakai oleh `gas deploy list` dan `gas deploy remove`.

## Planned Feature

Ada pilihan `apache` di prompt deploy, tetapi implementasi saat ini belum mendukung server selain Nginx. Jadi dukungan Apache harus dianggap sebagai planned feature, bukan capability aktif.

## Rekomendasi Operasional

- Jalankan `gas build` lebih dulu untuk setiap app yang akan diproxy.
- Biasakan memakai `gas deploy preview` sebelum overwrite config domain penting.
- Pakai `--reuse-existing yes` secara eksplisit di automation bila domain yang sama sering diupdate.
- Untuk perubahan berisiko, simpan backup dan biarkan `--test yes` aktif.

Setelah memahami deploy manual, langkah berikutnya adalah mengotomatiskan workflow ini lewat [GAS_CICD_GUIDE.md](./GAS_CICD_GUIDE.md).
