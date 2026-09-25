# Riwayat & Fase Pengembangan — Talvio

Dokumen ini merangkum proses pengembangan aplikasi **Talvio** (HRIS multi-tenant: absensi, izin/cuti, lembur, koreksi absensi, payroll otomatis) dari awal hingga kondisi saat ini, sebagai catatan progres untuk keperluan evaluasi/bimbingan.

## Ringkasan Proyek

| | |
|---|---|
| **Nama** | Talvio |
| **Jenis** | HRIS multi-tenant SaaS — tiap perusahaan yang mendaftar mendapat workspace terisolasi |
| **Backend** | Go 1.26, Gin (router), GORM (ORM), PostgreSQL |
| **Mobile** | Flutter, Riverpod (state management), GoRouter (routing), Dio (HTTP client) |
| **Autentikasi** | JWT (access + refresh token), setiap request tenant-aware lewat `company_id` di klaim token |
| **Storage foto** | Supabase Storage, upload selalu lewat backend (mobile tidak pernah pegang credential Supabase) |
| **Face verification** | Liveness detection (`google_mlkit_face_detection`) + face-matching on-device (MobileFaceNet via TFLite) |
| **Repo** | 3 folder: `talvio/` (spesifikasi & dokumen bersama), `talvio-backend/`, `talvio-mobile/` — masing-masing backend/mobile adalah git repo terpisah |

Spesifikasi teknis lengkap (ERD, API endpoint, logika bisnis, keputusan arsitektur) ada di `talvio/SPEC.md` — dokumen ini fokus ke **kronologi dan proses**, bukan spesifikasi.

## Metodologi

Pengembangan dilakukan **per-fase secara vertical slice** — setiap fase mengerjakan backend dan mobile sekaligus untuk satu kelompok fitur, sehingga bisa langsung diuji end-to-end sebelum lanjut ke fase berikutnya, bukan menyelesaikan seluruh backend dulu baru mobile (atau sebaliknya).

Alur kerja git: satu fitur/fix = satu branch (`feature/<nama>`), digabung ke `main` setelah build dan test lolos. Saat ada dua alur kerja berjalan bersamaan di repo yang sama, dipakai **git worktree** (folder kerja terpisah dari branch yang sama) supaya tidak saling menimpa file yang sedang diedit.

---

## Kronologi Fase

### Fase 0 — Registrasi Perusahaan & Onboarding
**20 September 2026**

Titik masuk sistem multi-tenant: sebuah perusahaan mendaftar (`POST /auth/register-company`), lalu HR admin pertamanya menjalankan wizard onboarding (lokasi kantor, jam kerja, kuota cuti, tanggal cutoff payroll, konfigurasi approval default).

Hardening keamanan ditambahkan di fase ini juga, sebelum fitur lain dibangun:
- Setiap request (kecuali `/health`) wajib membawa signature HMAC-SHA256 (`X-Timestamp` + `X-Signature`), sebagai lapisan pertahanan tambahan di luar JWT.
- Rate limiting per-IP di endpoint registrasi dan login.
- Backend menolak untuk boot (`log.Fatal`) kalau `JWT_SECRET`/`API_SIGNING_SECRET` kosong — tidak ada default diam-diam yang tidak aman.

### Fase 1 — Manajemen Karyawan & Departemen
**20 September 2026**

CRUD karyawan dan departemen, penugasan atasan (`supervisor_id`, self-referencing), soft-deactivate karyawan (bukan hard delete). Ditambahkan juga: standardisasi format tanggal (`YYYY-MM-DD` untuk field tanggal murni, backend menolak timestamp ISO8601 penuh), format Rupiah sebagai integer (bukan float), dan setup i18n mobile (Bahasa Indonesia default + English) dengan penerjemah error terpusat supaya pesan error mentah dari backend tidak pernah tampil langsung ke pengguna.

### Fase 2a — Absensi Inti
**20 September 2026**

Clock-in/clock-out dengan validasi geofencing (radius lokasi kantor), liveness check kamera sebelum submit, dan alur review HR untuk absensi di luar radius. Urutan pengecekan sengaja lokasi dulu baru kamera (GPS murah/cepat, kamera lebih berat), sesuai keputusan yang didokumentasikan di `SPEC.md`.

### Fase 2b — Face-Matching On-Device
**20 September 2026**

Merevisi keputusan awal (liveness-only) menjadi **liveness + face-matching**: foto live capture dibandingkan dengan foto profil karyawan menggunakan model MobileFaceNet yang berjalan sepenuhnya on-device (tanpa API cloud pihak ketiga, demi privasi data karyawan). Hasil pencocokan (skor + status match/uncertain/mismatch) disimpan di record absensi, bukan sekadar pass/fail biner, supaya HR punya konteks saat meninjau.

### Fase 3 — Izin/Cuti & Approval Routing
**21 September 2026**

Pengajuan cuti/izin/sakit dengan kuota otomatis untuk tipe `cuti`, plus **approval resolver** yang bisa diarahkan ke atasan langsung, delegasi, atau HR — dikonfigurasi per perusahaan per jenis permintaan (`approval_configs`), dipakai bersama oleh leave, lembur, dan review absensi di luar radius (`wfh_review`).

Pada fase ini juga ditemukan dan diperbaiki celah desain: menu review absensi sempat ter-gate HR-only di mobile padahal backend sudah mendukung supervisor biasa sebagai approver — diperbaiki supaya UI konsisten dengan resolver di backend.

### Fase 4–7 — Koreksi, Lembur, Laporan, Payroll, Pengumuman, Dashboard
**22 September 2026**

Empat fase sisa dari roadmap awal dikerjakan berurutan dalam satu hari:
- **Koreksi absensi** — pengajuan perbaikan jam masuk/pulang yang salah, selalu disetujui HR (tidak lewat resolver, sesuai keputusan di `SPEC.md`).
- **Lembur** — diajukan **setelah** clock-out (bukan rencana di muka), divalidasi terhadap `clock_out_at` aktual; klaim yang tidak didukung data absensi ditolak dan diarahkan untuk mengajukan koreksi dulu.
- **Laporan** — ringkasan absensi & cuti (personal maupun company-wide untuk HR), dengan export PDF/XLSX.
- **Payroll** — komponen gaji (tunjangan/potongan), generate payroll run berbasis periode cutoff, slip gaji per karyawan.
- **Pengumuman** — broadcast company-wide atau per-departemen.
- **Dashboard** — ringkasan agregat (absensi, cuti, lembur) di halaman utama.

### Hardening Pasca-MVP
**24 September 2026**

Setelah seluruh fase fungsional selesai, dilakukan audit terhadap kesiapan produksi dan ditemukan tiga celah yang diperbaiki:

1. **Release signing** — build release Android ternyata masih ditandatangani pakai debug key (APK seperti ini tidak bisa diunggah ke Play Store, dan siapa pun bisa menandatangani update palsu dengan debug key yang sama karena ikut ter-bundle di setiap instalasi Flutter). Dibuatkan keystore rilis sungguhan dan di-wire lewat `key.properties` (tidak masuk git).
2. **Export laporan tidak bisa diakses pengguna** — tombol export PDF/XLSX sebelumnya cuma menyimpan file ke folder internal aplikasi dan menampilkan path mentahnya di snackbar, tidak ada cara bagi pengguna untuk benar-benar membuka/mengirim filenya. Diperbaiki dengan membuka share sheet OS (`share_plus`) supaya pengguna bisa simpan/kirim ke mana pun.
3. **Push notification (FCM)** — sebelumnya belum diimplementasikan sama sekali meski sudah tercantum di spesifikasi tech stack. Dibangun penuh: backend mengirim push lewat Firebase Admin SDK ke setiap alur approval (leave, absensi pending-review, lembur, koreksi) dan broadcast pengumuman; mobile mendaftarkan device token dan menampilkan notifikasi. Seluruh mekanisme dirancang **aman-tanpa-konfigurasi** — kalau project Firebase belum disiapkan, semua fungsi lain tetap berjalan normal, push hanya diam sampai file konfigurasi (`google-services.json` + service account key) tersedia.

---

## Tantangan Teknis yang Ditemukan & Diselesaikan

Beberapa masalah yang butuh investigasi lebih dari sekadar baca pesan error:

- **Verifikasi wajah gagal terus-menerus** — root cause ditemukan lewat perbandingan langsung foto profil vs foto absen secara forensik: teks pada lanyard di foto profil terbaca **terbalik (cermin)**, sementara di foto absen normal. Penyebabnya kamera sistem Android (dipakai untuk upload foto profil) mem-flip hasil selfie kamera depan, sementara kamera custom aplikasi untuk absensi tidak. Model face-matching tidak *flip-invariant*, sehingga karyawan mana pun yang foto profilnya diambil lewat kamera sistem akan selalu gagal cocok. Solusi: satukan kedua jalur pengambilan foto lewat kamera custom yang sama.
- **Preview kamera terlihat lonjong/terdistorsi** — `CameraPreview` dipaksa mengisi `Stack(fit: StackFit.expand)` tanpa memperhatikan aspect ratio asli sensor kamera. Diperbaiki dengan pola `ClipRect` + `OverflowBox` + `FittedBox(BoxFit.cover)` yang standar untuk kasus ini.
- **Permission `INTERNET` hilang di build release** — ternyata hanya ada di manifest overlay debug/profile bawaan Flutter, bukan manifest utama, sehingga build release akan gagal total memanggil API mana pun (bug laten yang belum ketahuan karena belum pernah dites di mode release).
- **Plugin Gradle `google-services` gagal di-resolve** — plugin ini tidak mem-publish marker ke Gradle Plugin Portal, sehingga deklarasi lewat `plugins {}` DSL modern gagal; harus di-apply lewat mekanisme `buildscript classpath` klasik.
- **R8/ProGuard mematahkan build release** setelah model TFLite ditambahkan — build minifikasi menghapus kelas GPU-delegate yang direferensikan tapi tidak pernah dipakai (matching selalu jalan di CPU). Ditambahkan keep-rule yang eksplisit dengan alasan di komentar.

---

## Status Saat Ini

Seluruh 7 fase dari roadmap awal (`SPEC.md` bagian 6) sudah selesai di backend maupun mobile, terverifikasi lewat `go build`/`go test` dan `flutter analyze`/`flutter test` yang hijau di kedua repo. Tiga item hardening pasca-MVP (signing, export sharing, push notification) juga sudah selesai.

Yang masih terbuka sebagai pekerjaan lanjutan:
- Project Firebase (untuk push notification) belum dibuat — kode penerima/pengirimnya sudah siap, tinggal menyambungkan kredensial.
- Belum ada remote git (GitHub) — pekerjaan masih lokal di satu mesin.
- Beberapa batasan MVP yang memang didokumentasikan sebagai keputusan sadar (bukan bug): deteksi anti-fake-GPS ditunda, payroll run yang sudah final tidak auto-update kalau ada approval susulan.
- Pembaruan desain UI/UX (design system) dan fitur notifikasi in-app sedang berjalan sebagai iterasi lanjutan di luar cakupan 7 fase awal.
