# ⚡ Nova Downloader Pro

A modern, high-performance desktop media downloader built with Flutter. Designed for speed, aesthetic excellence, and seamless cross-platform desktop integration on **Windows**, **macOS**, and **Linux**.

---

## ✨ Features

- 🚀 **High-Speed Acceleration**: Multi-threaded segmented downloading powered by `yt-dlp` and `aria2c`.
- 🎨 **Adaptive Modern UI**: Complete Dark and Light themes with seamless live toggling and persistent preference storage.
- 🖼️ **Rich Thumbnails & Duration Overlay**: Visual feedback with actual video thumbnails, duration badges, and channel details.
- 📋 **Clipboard Auto-Detection**: Automatically detects copied media URLs from YouTube, Vimeo, and direct streams.
- 🔔 **System Tray Integration**: Run in the background without cluttering your taskbar.
- 📁 **Direct File & Folder Navigation**: Open completed media files and reveal them in Windows Explorer, macOS Finder, or Linux file managers.
- 🎯 **Playlist & Channel Batch Downloads**: Fetch entire playlists and selectively enqueue videos in customizable quality (4K, 1080p, 720p, or Audio MP3).

---

## 🛠️ Development & Building

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`^3.13` or newer)
- Visual Studio (Windows Desktop C++ workload) on Windows
- Xcode on macOS
- `clang`, `cmake`, `ninja-build`, `libgtk-3-dev` on Linux

### Run Locally

```bash
# Get dependencies
flutter pub get

# Run on your desktop
flutter run -d windows    # On Windows
flutter run -d macos      # On macOS
flutter run -d linux      # On Linux
```

### Build Release Executables

```bash
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

---

## 🚀 Releases & CI/CD

Release binaries are automatically compiled and published across **Windows**, **macOS**, and **Linux** via GitHub Actions whenever a release tag (e.g. `v1.0.0`) is pushed.

```bash
git tag v1.0.0
git push origin v1.0.0
```

---

## 📜 License

This project is licensed under the MIT License.
