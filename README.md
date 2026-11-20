<div align="center">

<img src="https://socialify.git.ci/zinedine1210/talvio-mobile/image?description=1&font=Inter&language=1&name=1&owner=0&pattern=Circuit+Board&theme=Dark" width="100%" alt="Talvio header"/>

<a href="https://github.com/zinedine1210/talvio-mobile">
  <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=20&duration=2800&pause=900&color=0EA5E9&center=true&vCenter=true&width=600&lines=Absen+dengan+GPS+%2B+Face+Liveness+%F0%9F%93%8D;Face-Matching+100%25+On-Device+%F0%9F%94%92;Approval+Routing+Fleksibel+per+Company+%E2%9A%99%EF%B8%8F;Izin+%C2%B7+Lembur+%C2%B7+Koreksi+%C2%B7+Payroll+%F0%9F%92%B0" alt="Talvio taglines"/>
</a>

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)
![Riverpod](https://img.shields.io/badge/State-Riverpod-40C4FF?style=flat-square&logo=flutter&logoColor=white)
![Go](https://img.shields.io/badge/Go-00ADD8?style=flat-square&logo=go&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white)
![Supabase](https://img.shields.io/badge/Storage-Supabase-3FCF8E?style=flat-square&logo=supabase&logoColor=white)
![Status](https://img.shields.io/badge/status-MVP%20functional-22C55E?style=flat-square)
[![CI](https://github.com/zinedine1210/talvio-mobile/actions/workflows/ci.yml/badge.svg)](https://github.com/zinedine1210/talvio-mobile/actions/workflows/ci.yml)

</div>

> [!NOTE]
> Repo ini adalah aplikasi mobile-nya. Backend REST API (Go + Gin + PostgreSQL) ada di repo terpisah, `talvio-backend`. Badge CI di atas jalanin `flutter analyze` + `flutter test` beneran lewat GitHub Actions tiap push, bukan gambar statis.

---

<div align="center">

| 📱 File Dart | 🧩 Layar | 🧪 Test | 🔌 Endpoint API | 🗂️ Modul Backend |
|:---:|:---:|:---:|:---:|:---:|
| **89** | **43** | **36 passing** | **66** | **11** |

</div>

## Daftar Isi

- [Kenapa Talvio](#kenapa-talvio)
- [Fitur per Modul](#fitur-per-modul)
- [Tampilan Aplikasi](#tampilan-aplikasi)
- [Arsitektur](#arsitektur)
- [Role & Akses](#role--akses)
- [Approval Routing](#approval-routing)
- [Keamanan](#keamanan)
- [Tech Stack](#tech-stack)
- [Referensi API](#referensi-api)
- [Struktur Proyek](#struktur-proyek)
- [Menjalankan Secara Lokal](#menjalankan-secara-lokal)
- [Testing](#testing)
- [Progress](#progress)
- [Dokumentasi UML](#dokumentasi-uml)
- [Tim Pengembang](#tim-pengembang)

## Kenapa Talvio

Sebagian besar aplikasi presensi kantor cuma verifikasi lokasi, gampang dikelabui foto orang lain atau titip absen. Talvio menutup dua celah itu sekaligus: **geofencing** (harus dalam radius kantor) **+ face liveness dan face-matching yang jalan langsung di HP**, jadi tidak ada foto wajah karyawan yang keluar ke server pihak ketiga, sekaligus tetap murah dijalankan karena tidak butuh API cloud berbayar per verifikasi.

Alur approval (izin, lembur, review absen di luar radius / wajah tidak cocok) mengikuti satu aturan yang sama: siapa yang berhak menyetujui diatur lewat konfigurasi per perusahaan (`approval_configs`), bukan di-hardcode di kode. Pengecualiannya koreksi absensi dan `missing_clockout`, yang sengaja selalu ke HR. Lihat [Approval Routing](#approval-routing).

## Fitur per Modul

| Modul | Yang bisa dilakukan |
|---|---|
| 📍 **Absensi** | Clock-in/out dengan cek radius lokasi, liveness check, dan face-matching on-device terhadap foto profil |
| 🌴 **Izin & Cuti** | Ajukan cuti/izin/sakit, kuota tahunan terpotong otomatis, approval lewat resolver |
| ⏰ **Lembur** | Diklaim setelah clock-out, divalidasi terhadap jam pulang aktual, tidak bisa asal klaim |
| 📝 **Koreksi Absensi** | Revisi jam masuk/pulang yang keliru, selalu lewat approval HR |
| 💰 **Payroll** | Komponen gaji custom per karyawan, generate slip otomatis per periode cutoff |
| 📊 **Laporan** | Ringkasan absensi & cuti (personal / company-wide), export PDF & XLSX |
| 📢 **Pengumuman** | Broadcast ke seluruh perusahaan atau satu departemen |
| 🔔 **Notifikasi** | Item yang butuh approval tampil sebagai badge, bukan menu yang numpuk di beranda |

## Tampilan Aplikasi

<div align="center">

**Karyawan**

| Dashboard | Absensi | Verifikasi Wajah | Ajukan Permohonan |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/dashboard%20karyawan.jpeg" width="200"/> | <img src="docs/screenshots/absensi%20karyawan.jpeg" width="200"/> | <img src="docs/screenshots/absensi.jpeg" width="200"/> | <img src="docs/screenshots/ajukan%20permohonan.jpeg" width="200"/> |

**HR Admin**

| Dashboard | Persetujuan | Tambah Karyawan |
|:---:|:---:|:---:|
| <img src="docs/screenshots/dashboard%20hr.jpeg" width="200"/> | <img src="docs/screenshots/persetujuan%20hr.jpeg" width="200"/> | <img src="docs/screenshots/tambah%20karyawan.jpeg" width="200"/> |

| Master Organisasi | Approval & Departemen | Pengaturan Perusahaan |
|:---:|:---:|:---:|
| <img src="docs/screenshots/master%20organisasi.jpeg" width="200"/> | <img src="docs/screenshots/approval%20and%20departemen%20setting.jpeg" width="200"/> | <img src="docs/screenshots/pengaturan%20perusahaan.jpeg" width="200"/> |

</div>

## Arsitektur

```mermaid
graph TD
    Mobile["📱 talvio-mobile<br/>Flutter"] -- "HTTP + HMAC signature" --> API["🔧 talvio-backend<br/>Go + Gin"]
    API --> DB[("PostgreSQL")]
    API -- "upload lewat backend saja" --> Storage[("Supabase Storage")]
    Mobile -. "baca foto profil<br/>(URL publik)" .-> Storage
    Mobile -. "face-match jalan di HP,<br/>tidak lewat API" .-> Mobile
```

### Alur Clock-In (detail interaksi)

```mermaid
sequenceDiagram
    actor U as Karyawan
    participant M as Mobile (Flutter)
    participant B as Backend (Go)
    participant S as Supabase Storage
    participant D as PostgreSQL

    U->>M: Buka layar absen
    M->>M: Cek GPS, di luar radius? wajib isi catatan
    M->>M: Liveness check (ML Kit, live di kamera)
    M->>M: Face-match vs foto profil (TFLite, on-device)
    M->>B: POST /attendance/clock-in<br/>(JWT + HMAC signature + foto + skor face-match)
    B->>B: Verifikasi signature & company_id dari JWT
    B->>D: Tutup absen kemarin yang belum clock-out<br/>(jadi missing_clockout), cek belum absen hari ini
    B->>B: Hitung ulang radius (haversine, otoritatif)<br/>+ status terlambat
    B->>S: Upload foto absensi
    S-->>B: URL foto
    opt Di luar radius / face-match uncertain atau mismatch
        B->>D: Resolve approver (wfh_review)
    end
    B->>D: Simpan attendance record<br/>(status: hadir / pending_review)
    opt Status pending_review
        B->>D: Notifikasi ke approver
    end
    B-->>M: 201 Created
    M-->>U: "Absen masuk berhasil"
```

### Siklus Status Absensi

Status absensi mengikuti siklus berikut. Perubahan otomatis hanya terjadi saat clock-out atau saat absen yang lewat hari dibuka lagi; selebihnya lewat review approver atau koreksi yang disetujui HR:

```mermaid
stateDiagram-v2
    [*] --> hadir: clock-in dalam radius, wajah cocok
    [*] --> pending_review: clock-in di luar radius / face-match uncertain atau mismatch
    hadir --> pending_review: clock-out di luar radius / face-match uncertain atau mismatch
    hadir --> missing_clockout: belum clock-out, terdeteksi hari berikutnya
    pending_review --> approved_wfh: approver setujui
    pending_review --> rejected: approver tolak
    missing_clockout --> approved_wfh: HR setujui
    missing_clockout --> rejected: HR tolak
    pending_review --> hadir: koreksi disetujui HR
    missing_clockout --> hadir: koreksi disetujui HR
```

`missing_clockout` tidak dijalankan cron: dicek ulang tiap karyawan clock-in, clock-out, atau membuka daftar absensinya. Approver `pending_review` ditentukan resolver `wfh_review` (bisa supervisor), sedangkan `missing_clockout` selalu ke HR.

> [!IMPORTANT]
> Karyawan tidak pernah benar-benar terkunci dari absen. Kalau face-match gagal berkali-kali, sistem tetap menerima submit dan menandainya `pending_review` untuk ditinjau HR manual lewat foto yang tersimpan, tidak ada skenario karyawan asli gagal absen total karena sistem.

## Role & Akses

| | Employee | HR Admin |
|---|:---:|:---:|
| Absen, ajukan izin/lembur/koreksi | ✅ | ❌ (pakai akun karyawan terpisah bila perlu) |
| Lihat slip gaji & pengumuman sendiri | ✅ | - |
| Jadi approver (kalau ditunjuk supervisor/delegate) | ✅ | ✅ |
| Kelola karyawan, departemen, approval routing | ❌ | ✅ |
| Kelola komponen gaji & jalankan payroll | ❌ | ✅ |
| Tinjau koreksi absensi | ❌ | ✅ (satu-satunya, tidak bisa didelegasikan) |

## Approval Routing

HR mengatur approver per jenis pengajuan lewat `PUT /company/approval-configs`. Resolver yang sama dipakai semua jenis di bawah:

| Jenis (`request_type`) | Dipakai untuk |
|---|---|
| `leave` | Izin, cuti, sakit |
| `overtime` | Klaim lembur |
| `wfh_review` | Absen `pending_review` (di luar radius / face-match uncertain atau mismatch) |

| Mode | Approver | Fallback |
|---|---|---|
| `hr` (default kalau belum dikonfigurasi) | HR admin aktif mana pun | - |
| `supervisor` | `supervisor_id` milik karyawan | HR admin kalau supervisor kosong |
| `delegate` | Karyawan yang ditunjuk (`delegate_employee_id`) | HR admin kalau delegate kosong |

Koreksi absensi dan `missing_clockout` tidak lewat resolver ini, selalu ke HR.

## Keamanan

- Setiap request ke backend (kecuali `/health`) ditandatangani HMAC-SHA256, ditolak kalau timestamp meleset > 5 menit
- Secret HMAC ikut ter-compile di aplikasi (`lib/core/api_signing.dart`), jadi fungsinya lapisan tambahan untuk menahan skrip/bot yang menembak API langsung, bukan rahasia sungguhan. Autentikasi yang sebenarnya tetap JWT dari login
- `company_id` selalu diambil dari klaim JWT lewat middleware, tidak pernah dipercaya dari input client
- Face-matching 100% on-device (TFLite/MobileFaceNet), foto wajah tidak pernah dikirim ke pihak ketiga
- Rate limiting per-IP di endpoint register & login
- `JWT_SECRET` dan `API_SIGNING_SECRET` wajib diisi, backend menolak menyala kalau kosong

## Tech Stack

| Layer | Pilihan |
|---|---|
| Mobile | Flutter, Riverpod, GoRouter, Dio |
| Face verification | `google_mlkit_face_detection` (liveness) + `tflite_flutter` (MobileFaceNet, on-device matching) |
| Backend | Go, Gin, GORM, PostgreSQL, JWT |
| Storage foto | Supabase Storage, diakses lewat backend saja |

## Referensi API

<details>
<summary><b>66 endpoint (di luar <code>/health</code>), dikelompokkan per modul (klik untuk buka)</b></summary>
<br/>

| Modul | Endpoint |
|---|---|
| Auth / Company | `POST /auth/register-company`, `POST /auth/login`, `POST /auth/refresh`, `GET /company/me`, `PUT /company/settings`, `GET/POST/PUT/DELETE /company/locations` |
| Onboarding | `POST /company/onboarding` |
| Employees | `GET/POST /employees`, `GET/PUT/DELETE /employees/:id`, `GET /employees/me`, `POST /employees/:id/photo`, `GET/POST/PUT/DELETE /departments` |
| Attendance | `POST /attendance/clock-in`, `POST /attendance/clock-out`, `GET /attendance/me`, `GET /attendance`, `GET /attendance/pending-review`, `POST /attendance/:id/review` |
| Correction | `POST /attendance/:id/corrections`, `GET /corrections`, `POST /corrections/:id/approve\|reject` |
| Leave | `POST /leave-requests`, `GET /leave-requests/me`, `GET /leave-requests`, `POST /leave-requests/:id/approve\|reject`, `GET /leave-quotas/me` |
| Overtime | `POST /overtime-requests`, `GET /overtime-requests/me`, `GET /overtime-requests`, `POST /overtime-requests/:id/approve\|reject` |
| Approval Config | `GET/PUT /company/approval-configs` |
| Payroll | `GET/POST /payroll/salary-components`, `PUT /employees/:id/salary`, `POST/GET/DELETE /employees/:id/salary-components`, `POST /payroll/runs`, `GET /payroll/runs`, `GET /payroll/runs/:id/details`, `GET /payroll/slips/me`, `GET /payroll/slips/:employeeId` |
| Reports | `GET /reports/attendance-summary`, `GET /reports/leave-summary` |
| Announcement | `POST/GET /announcements` |
| Dashboard | `GET /dashboard/summary` |

</details>

## Struktur Proyek

```
lib/
  core/          # api client, router, tema, formatter, signing
  features/
    auth/ onboarding/ company/ employee/ attendance/
    leave/ overtime/ correction/ payroll/
    report/ announcement/ dashboard/
    approval/ organization/ request/   # hub menu, presentation/ saja
  l10n/          # ID + EN
```
Feature umumnya: `data/` (model + panggilan API), `presentation/` (layar + widget), `providers/` (Riverpod). Pengecualian: `approval/`, `organization/`, `request/` cuma layar hub yang menggabungkan menu feature lain.

## Menjalankan Secara Lokal

```bash
# backend dulu, lihat README talvio-backend untuk .env
cd talvio-backend && go run ./cmd/api

# lalu mobile
cd talvio-mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<ip-backend>:8081
```

> [!TIP]
> HP fisik lewat USB: `adb reverse tcp:8081 tcp:8081`, lalu pakai `API_BASE_URL=http://localhost:8081`. Emulator Android otomatis pakai `10.0.2.2` sebagai alias localhost, tidak perlu setting tambahan.

> [!WARNING]
> `apiSigningSecret` di `lib/core/api_signing.dart` harus sama persis dengan `API_SIGNING_SECRET` di `.env` backend. Kalau beda, semua request ditolak dengan error signature tidak valid.

Aplikasi butuh izin **kamera** (liveness + foto absen) dan **lokasi** (geofencing). Tanpa keduanya, layar absen tidak bisa dipakai.

Build APK untuk dibagikan (HP lain di WiFi yang sama dengan laptop backend):

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<ip-lan-laptop>:8081
# hasil: build/app/outputs/flutter-apk/app-release.apk
```

URL backend ikut ter-compile, jadi APK harus di-build ulang kalau IP laptop berubah.

## Testing

```bash
flutter analyze
flutter test
```

36 test di `test/` menutup logika murni yang paling rawan salah: signing HMAC (`api_signing_test`), penentuan tombol clock-in/out (`attendance_status_test`), threshold face-match (`face_matching_test`), durasi cuti (`leave_duration_test`), formatter, dan penerjemah error API. CI menjalankan dua perintah di atas tiap push / PR ke `main`.

## Progress

| Fase | Cakupan | Status |
|---|---|:---:|
| 0 | Registrasi perusahaan + onboarding | ✅ |
| 1 | Manajemen karyawan & departemen | ✅ |
| 2 | Absensi + geofencing + face liveness/matching | ✅ |
| 3 | Izin/cuti + approval routing | ✅ |
| 4 | Koreksi absensi + lembur | ✅ |
| 5 | Laporan absensi & cuti | ✅ |
| 6 | Payroll | ✅ |
| 7 | Pengumuman, dashboard, notifikasi in-app | ✅ |

Detail lengkap tiap kebutuhan fungsional/non-fungsional: lihat [`SRS_Kelompok 3.pdf`](./SRS_Kelompok%203.pdf).

## Dokumentasi UML

Tugas Rekayasa Perangkat Lunak, dibuat berdasarkan sistem Talvio yang sebenarnya (bukan contoh generik).

- [x] [Desain Figma](https://www.figma.com/design/u71ZBqEkA7JzoCfoOQCuNo/Talvio?node-id=1-61&p=f&t=RQaqLMxhF5fZqVsf-0)
- [x] [Use Case Diagram](https://app.diagrams.net/#G1QBJ3MdgNIFTdu57USKDvqCQ35i_suv76#%7B%22pageId%22%3A%224o1dcDgJ-3b9LBgPc4fq%22%7D)
- [x] [Activity Diagram](https://app.diagrams.net/#G1QBJ3MdgNIFTdu57USKDvqCQ35i_suv76#%7B%22pageId%22%3A%22XAgKsTMK8KjJrySv46gA%22%7D)
- [x] [Sequence Diagram](https://app.diagrams.net/#G1QBJ3MdgNIFTdu57USKDvqCQ35i_suv76#%7B%22pageId%22%3A%22wB4YMA15K5CTAmcyD7ON%22%7D)
- [x] [State Diagram HR](https://app.diagrams.net/#G1QBJ3MdgNIFTdu57USKDvqCQ35i_suv76#%7B%22pageId%22%3A%22eX-l3HYi6hvrXMxnWAc7%22%7D)
- [x] [State Diagram Karyawan](https://app.diagrams.net/#G1QBJ3MdgNIFTdu57USKDvqCQ35i_suv76#%7B%22pageId%22%3A%223rERcR2Dnczq-AJLcoHC%22%7D)
- [x] [Class Diagram](https://app.diagrams.net/#G1QBJ3MdgNIFTdu57USKDvqCQ35i_suv76#%7B%22pageId%22%3A%22qCH8nvdlj9Bhj-ZHw-lF%22%7D)
- [x] [Object Diagram](https://app.diagrams.net/#G1QBJ3MdgNIFTdu57USKDvqCQ35i_suv76#%7B%22pageId%22%3A%22RQh_0sdt3afVbC8N4Hr6%22%7D)
- [x] [Deployment Diagram](https://app.diagrams.net/#G1QBJ3MdgNIFTdu57USKDvqCQ35i_suv76#%7B%22pageId%22%3A%22fOwBbhYUbR6GrOBD7k8g%22%7D)
- [x] [Test Case (Black-Box & White-Box)](https://docs.google.com/spreadsheets/d/1oCkihB85JRCNpwDmMdBWMJdH3lt9MZSzsr59uGtn_fg/edit?hl=id&gid=482033157#gid=482033157)

## Tim Pengembang

| NPM | Nama | Modul |
|:---:|:---:|---|
| `202343501560` | `Zinedine Ziddan Fahdlevy` | `Absensi (Laporan, Approval), Dashboard, Pengumuman` |
| `202343501557` | `Dela Ramadani` | `Izin/Cuti/Lembur, Laporan, Approval` |
| `202343501558` | `Haura Nahdah` | `Management Karyawan, Departemen` |

`Rekayasa Perangkat Lunak`, `Universitas Indraprasta PGRI`

## Kredit

Model `assets/models/mobilefacenet.tflite` diambil dari [MCarlomagno/FaceRecognitionAuth](https://github.com/MCarlomagno/FaceRecognitionAuth), lisensi BSD 3-Clause. Detail dan teks lisensi lengkap: [`assets/models/NOTICE.md`](./assets/models/NOTICE.md).

---

<p align="center"><sub>Talvio, HRIS multi-tenant, dibangun bertahap Fase 0 s/d 7. Sekarang sudah fase 7</sub></p>
