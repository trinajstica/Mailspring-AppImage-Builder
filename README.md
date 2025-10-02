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
```

### Optional flags

- `--verbose` — show detailed build output from all commands.
- `-b` — after building the AppImage, create an **autostart `.desktop` file** in  
  `~/.config/autostart/` that will launch the AppImage with the `-b` argument (background mode) when you log in.
 - `--remove` — remove installed artifacts (AppImage, icon, desktop entries, autostart entry, downloaded .deb, local appimagetool) from the system and exit; non-interactive.

Example:

```bash
./build-mailspring-appimage.sh --verbose -b
```

Remove installed artifacts (non-interactive):

```bash
./build-mailspring-appimage.sh --remove
```

This will:
1. Build the Mailspring AppImage with detailed output.
2. Install a `.desktop` file in `~/.local/share/applications/`.
3. Create an autostart `.desktop` file in `~/.config/autostart/` to run Mailspring with `-b` at login.

---

## 📂 Output

- **`Mailspring.AppImage`** — the portable application file in your current directory.
- **`mailspring.png`** — the application icon (placed in the same directory as the AppImage).
- **`~/.local/share/applications/mailspring.desktop`** — launcher entry for your desktop environment.
- *(If `-b` used)* **`~/.config/autostart/mailspring-background.desktop`** — autostart entry for background launch.

---

## 🛠 Requirements

Make sure these tools are installed on your system:

- `curl`
- `grep`
- `wget`
- `ar`
- `tar`
- `uname`

If `appimagetool` is not installed system-wide, the script will download a local copy automatically.

Additional recommended tools (for extracting compressed .deb payloads):

- `xz-utils` (for .xz extraction)
- `gzip` and `bzip2` (for .gz/.bz2 extraction)

Note: the script handles common compression formats (xz, gz, bz2) when extracting `.deb` payloads. Running in a clean shell environment is recommended for predictable results.

---

---

## 📜 License

MIT — see [LICENSE](LICENSE) file for details.
