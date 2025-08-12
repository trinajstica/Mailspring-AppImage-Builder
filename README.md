# Mailspring AppImage Builder

A lightweight Bash script to automatically build a portable [AppImage](https://appimage.org/) for [Mailspring](https://getmailspring.com) from the official `.deb` release.

Inspired by: [zydou/Mailspring-Linux](https://github.com/zydou/Mailspring-Linux)  
Author: Barko  
Contributor: SimOne 😊  
License: MIT

---

## ✨ Features

- Downloads the latest release of Mailspring from GitHub
- Extracts the `.deb` package contents
- Assembles a clean AppDir structure
- Builds an AppImage using `appimagetool`
- Works in your **current working directory**
- Supports `--verbose` mode for detailed output
- Optional `-b` flag to create an **autostart entry** that launches Mailspring in background mode at system login

---

## 🚀 Usage

```bash
./build-mailspring-appimage.sh
