# Contributing to Talvio

Talvio adalah HRIS multi-tenant (absensi, izin/cuti, lembur, koreksi absensi, payroll) yang terdiri dari tiga folder terpisah:

| Folder | Isi |
|---|---|
| `talvio/` | Folder umbrella, `SPEC.md` (spesifikasi teknis lengkap), Postman collection, dan dokumen ini. Bukan git repo. |
| `talvio-backend/` | REST API, Go, Gin, GORM, PostgreSQL. Git repo sendiri. |
| `talvio-mobile/` | Aplikasi mobile, Flutter, Riverpod, GoRouter, Dio. Git repo sendiri. |

Baca `SPEC.md` dulu sebelum mulai kerja, semua keputusan arsitektur (multi-tenant scoping, format tanggal/uang, alur clock-in/out, dsb.) didokumentasikan di sana, bukan diputuskan ulang tiap sesi.

## 1. Prasyarat

- Go 1.26+
- Flutter 3.38+ (Dart 3.10+)
- PostgreSQL 14+ berjalan lokal
- Android Studio / Xcode (buat build & test mobile)
- `adb` (Android SDK platform-tools) kalau mau test di device fisik

## 2. Setup Backend

```bash
cd talvio-backend
cp .env.example .env   # isi DATABASE_URL, JWT_SECRET, API_SIGNING_SECRET, kredensial Supabase, dst.
go mod download
go run cmd/api/main.go
```

Backend gagal boot (`log.Fatal`) kalau `JWT_SECRET` atau `API_SIGNING_SECRET` kosong, ini sengaja, tidak ada fallback diam-diam ke default yang tidak aman. Database di-migrasi otomatis lewat GORM `AutoMigrate` saat boot, tidak perlu migration tool terpisah.

Verifikasi: `curl http://localhost:8081/health` → `{"status":"ok"}`.

## 3. Setup Mobile

```bash
cd talvio-mobile
flutter pub get
flutter run -d <device-id>
```

**Konek ke backend lokal:**
- Emulator Android: otomatis pakai `http://10.0.2.2:<port>` (alias bawaan emulator ke host).
- Device fisik lewat USB: jalankan `adb reverse tcp:<port> tcp:<port>` dulu, lalu override base URL:
  ```bash
  flutter run --dart-define=API_BASE_URL=http://localhost:<port>
  ```

**Build release (APK signed):**
Butuh `android/key.properties` (gitignored) yang menunjuk ke keystore release, lihat [dokumentasi resmi Flutter](https://flutter.dev/to/reference-keystore) untuk cara generate keystore-nya. Tanpa file ini, build release akan gagal (bukan diam-diam jatuh ke debug key).

**Push notification (FCM):**
Kode penerimaan push sudah ada (`lib/core/push_notifications.dart`) tapi jadi no-op sampai `android/app/google-services.json` (dari Firebase Console) ditaruh di tempatnya, dan backend diberi `FIREBASE_SERVICE_ACCOUNT_PATH` yang valid.

## 4. Testing

```bash
# Backend
cd talvio-backend
go build ./...
go vet ./...
go test ./...

# Mobile
cd talvio-mobile
flutter analyze
flutter test
```

Semua PR/merge ke `main` wajib lolos keduanya sebelum digabung. Jangan skip test yang gagal dengan `t.Skip()`/`skip:` tanpa alasan yang didokumentasikan.

## 5. Alur Git

- `main` = selalu dalam kondisi siap pakai di kedua repo.
- **Satu fitur/fix = satu branch** (`feature/<nama>` atau `fix/<nama>`), di-merge ke `main` setelah diverifikasi jalan (build + test hijau), tidak menunggu review manual per merge untuk proyek solo ini.
- **Kerja paralel (multi-sesi/multi-orang di repo yang sama):** pakai `git worktree add ../<nama-folder> -b <branch>` supaya tiap sesi kerja di working directory terpisah dan tidak saling menimpa file yang sedang di-edit sesi lain. Cek `git status` di working tree utama dulu sebelum mulai, kalau ada uncommitted changes dari sesi lain, jangan disentuh (jangan `stash`/`checkout` paksa), tunggu sampai di-commit.
- Hapus worktree yang sudah fully-merged (`git worktree remove <path>` lalu `git branch -d <branch>`) biar tidak menumpuk folder.

### Format pesan commit

Mengikuti pola Conventional Commits yang sudah dipakai di riwayat repo:

```
<type>(<scope>): <ringkasan singkat>

<body opsional: kenapa, bukan apa, reviewer sudah bisa baca diff>
```

Type yang dipakai: `feat`, `fix`, `refactor`, `style` (perubahan visual/layout, bukan CSS), `chore`, `security`, `test`, `merge`. Contoh nyata dari riwayat: `feat(leave): Fase 3 - leave requests, approval, approval config UI`, `fix(attendance): stop stretching the camera preview into an oval`.

## 6. Konvensi Kode

- **Tenant scoping**: `company_id` **selalu** diambil dari klaim JWT lewat middleware, tidak pernah dari body/query param client. Setiap query baru ke tabel yang scoped-per-company wajib filter `company_id`.
- **Format tanggal**: API pakai `YYYY-MM-DD` untuk field tanggal murni, backend menolak timestamp ISO8601 penuh untuk field itu. Tampilan mobile pakai format panjang Indonesia (`lib/core/formatters.dart`).
- **Uang**: integer (Rupiah), bukan float/decimal, di semua kolom nominal.
- **Backend**: struktur per-modul flat 3-lapis (`handler` → `service` → `repository`/GORM langsung), lihat `internal/modules/<nama>/`. Tidak ada clean-architecture berlebihan.
- **Mobile**: struktur feature-first (`lib/features/<nama>/{data,presentation,providers}/`).
- **Jangan over-engineer**: kalau ada keputusan yang sengaja disederhanakan untuk MVP (mis. tidak ada cron/scheduler, tidak ada anti-fake-GPS), itu didokumentasikan lewat komentar `// ponytail: ...` di kode yang menyebutkan batasannya dan kapan perlu di-upgrade, baca komentar itu sebelum "memperbaiki" sesuatu yang sebenarnya sengaja.

## 7. Melaporkan Bug / Mengajukan Perubahan

Belum ada remote GitHub untuk proyek ini (kerja masih lokal). Diskusikan perubahan besar (skema database, kontrak API, alur approval) dengan pemilik proyek sebelum mulai implementasi, cek `SPEC.md` dulu untuk memastikan itu belum diputuskan/didokumentasikan di sana.
