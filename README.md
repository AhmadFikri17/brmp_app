# Aplikasi Tanika - Weather App

Aplikasi cuaca berbasis Flutter untuk monitoring data cuaca.

## Versi Flutter

Project ini menggunakan:
- **Flutter**: 3.41.6 (stable channel)
- **Dart**: 3.11.4
- **DevTools**: 2.54.2

## Prasyarat

Sebelum memulai, pastikan komputer Anda memiliki:
- Koneksi internet yang stabil
- Minimal 10GB ruang penyimpanan kosong
- Windows 10 atau lebih tinggi

## Langkah-langkah Instalasi

### 1. Install Git

1. Download Git dari [https://git-scm.com/download/win](https://git-scm.com/download/win)
2. Jalankan installer yang sudah didownload
3. Ikuti wizard instalasi (gunakan pengaturan default)
4. Setelah selesai, buka Command Prompt dan verifikasi instalasi:
   ```bash
   git --version
   ```

### 2. Install Flutter

1. Download Flutter SDK dari [https://docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows)
2. Extract file zip ke lokasi yang diinginkan, misalnya: `C:\src\flutter`
3. Tambahkan Flutter ke PATH environment variable:
   - Buka Start Menu, cari "Environment Variables"
   - Klik "Edit the system environment variables"
   - Klik "Environment Variables"
   - Di bagian "User variables", pilih "Path" lalu klik "Edit"
   - Klik "New" dan tambahkan path: `C:\src\flutter\bin`
   - Klik OK untuk menyimpan
4. Restart Command Prompt atau PowerShell
5. Verifikasi instalasi Flutter:
   ```bash
   flutter --version
   ```

### 3. Jalankan Flutter Doctor

Flutter Doctor akan mengecek kelengkapan instalasi dan memberikan rekomendasi:

```bash
flutter doctor
```

Ikuti saran yang diberikan oleh Flutter Doctor untuk melengkapi instalasi, seperti:
- **Android Studio** (opsional - hanya jika ingin menggunakan emulator Android atau Android Studio sebagai editor)
- **Command-line tools** untuk Android SDK (wajib untuk development Android)
- Accept Android licenses: `flutter doctor --android-licenses`

**Catatan**: Untuk development dengan VS Code saja, Anda tidak perlu install Android Studio. Cukup install Android SDK Command-line Tools untuk build aplikasi Android.

### 4. Install Visual Studio Code

1. Download VS Code dari [https://code.visualstudio.com/](https://code.visualstudio.com/)
2. Install VS Code dengan mengikuti wizard instalasi
3. Buka VS Code

### 5. Install Extension Flutter di VS Code

1. Buka VS Code
2. Klik icon Extensions di sidebar kiri (atau tekan `Ctrl+Shift+X`)
3. Cari "Flutter" di search box
4. Install extension "Flutter" (by Dart Code)
5. Extension Dart akan otomatis terinstall sebagai dependency

### 6. Clone Repository Project

1. Buka Command Prompt atau PowerShell
2. Navigasi ke folder tempat Anda ingin menyimpan project:
   ```bash
   cd D:\magang\aplikasi
   ```
3. Clone repository:
   ```bash
   git clone https://github.com/AhmadFikri17/brmp_app.git
   ```
4. Masuk ke folder project:
   ```bash
   cd brmp_app
   ```

### 7. Install Dependencies

Setelah clone repository, install semua dependencies yang dibutuhkan:

```bash
flutter pub get
```

### 8. Jalankan Aplikasi

1. Pastikan device (emulator/physical device) sudah terhubung. Cek dengan:
   ```bash
   flutter devices
   ```
2. Jalankan aplikasi:
   ```bash
   flutter run
   ```

## Troubleshooting

### Flutter command not found
- Pastikan Flutter sudah ditambahkan ke PATH
- Restart terminal/command prompt setelah menambahkan ke PATH

### Flutter Doctor menunjukkan error
- Ikuti instruksi yang diberikan oleh Flutter Doctor
- Install tools yang dibutuhkan sesuai rekomendasi

### Pub get error
- Pastikan koneksi internet stabil
- Coba jalankan `flutter clean` kemudian `flutter pub get` lagi

### Device tidak terdeteksi
- Untuk Android: Aktifkan USB Debugging di device
- Untuk emulator: Pastikan Android Studio dan emulator sudah terinstall
- Jalankan `flutter doctor` untuk cek konfigurasi

## Struktur Project

```
brmp_app/
├── android/          # Konfigurasi Android
├── ios/              # Konfigurasi iOS
├── lib/              # Source code utama
├── test/             # Unit tests
├── pubspec.yaml      # Dependencies dan konfigurasi project
└── README.md         # Dokumentasi project
```

## Kontribusi

Untuk berkontribusi pada project ini:
1. Fork repository
2. Buat branch baru (`git checkout -b feature/AmazingFeature`)
3. Commit perubahan (`git commit -m 'Add some AmazingFeature'`)
4. Push ke branch (`git push origin feature/AmazingFeature`)
5. Buat Pull Request

## Lisensi

[Tambahkan informasi lisensi di sini]

## Kontak

Ahmad Fikri - [https://github.com/AhmadFikri17](https://github.com/AhmadFikri17)

Project Link: [https://github.com/AhmadFikri17/brmp_app](https://github.com/AhmadFikri17/brmp_app)
