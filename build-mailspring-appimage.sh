#!/bin/bash

# Fail fast, treat unset variables as errors and make pipelines fail on first failed command
set -euo pipefail
IFS=$'\n\t'

# ================================================
#  Check if required external tools are installed
# ================================================
required_tools=(curl grep wget ar tar uname)

# initialize
missing=false

for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        echo "❌ Error: Tool '$tool' is not installed. Please install it and try again."
        missing=true
    fi
done

if [ "$missing" = true ]; then
    exit 1
fi

# ========================================================
#  Script for building Mailspring AppImage
#  Author: Barko
#  Contributor: SimOne 😊
#  Source/Idea: https://github.com/zydou/Mailspring-Linux
#  License: MIT License
#  Description: This script downloads, extracts, and builds
#    an AppImage for the Mailspring application. Everything
#    is executed in the current working directory of the
#    user. Use the --verbose flag to show full command output;
#    otherwise, only high-level progress messages are shown.
#    Add -b to also create an autostart entry that launches
#    the AppImage with the -b (background) argument.
# ========================================================

# -----------------------------
# Parse flags: --verbose and -b
# -----------------------------
VERBOSE=false
AUTOSTART_BG=false
REMOVE_ONLY=false

while [ $# -gt 0 ]; do
  case "$1" in
    --verbose)
      VERBOSE=true
      shift
      ;;
    -b)
      AUTOSTART_BG=true
      shift
      ;;
        --remove)
            REMOVE_ONLY=true
            shift
            ;;
    *)
      echo "ℹ️  Ignoring unknown argument: $1"
      shift
      ;;
  esac
done

echo "========================================"
echo " Script: Build Mailspring AppImage"
echo " Author: Barko"
echo " Contributor: SimOne 😊"
echo " Source/Idea: https://github.com/zydou/Mailspring-Linux"
echo "========================================"
echo ""

APP=mailspring
ROOT="$(pwd)"
VERSION="${VERSION:-}"

# Paths for removal (computed later when needed)
APPIMAGE_PATH="$ROOT/$APP.AppImage"
ICON_PATH="$ROOT/$APP.png"
DESKTOP_FILE="$HOME/.local/share/applications/$APP.desktop"
AUTOSTART_FILE="$HOME/.config/autostart/${APP}-background.desktop"
LOCAL_APPIMAGETOOL="$ROOT/appimagetool"

# Remove-installed-artifacts mode
if [ "$REMOVE_ONLY" = true ]; then
    echo "🧹 Removal mode: removing AppImage, icons, desktop entries and local appimagetool if present..."
    [ -f "$APPIMAGE_PATH" ] && rm -v "$APPIMAGE_PATH" || echo "- $APPIMAGE_PATH not found"
    [ -f "$ICON_PATH" ] && rm -v "$ICON_PATH" || echo "- $ICON_PATH not found"
    if [ -f "$DESKTOP_FILE" ]; then
        rm -v "$DESKTOP_FILE"
        echo "- Removed desktop file: $DESKTOP_FILE"
    else
        echo "- Desktop file not found: $DESKTOP_FILE"
    fi
    if [ -f "$AUTOSTART_FILE" ]; then
        rm -v "$AUTOSTART_FILE"
        echo "- Removed autostart file: $AUTOSTART_FILE"
    else
        echo "- Autostart file not found: $AUTOSTART_FILE"
    fi
    if [ -f "$LOCAL_APPIMAGETOOL" ]; then
        rm -v "$LOCAL_APPIMAGETOOL"
        echo "- Removed local appimagetool: $LOCAL_APPIMAGETOOL"
    else
        echo "- Local appimagetool not found: $LOCAL_APPIMAGETOOL"
    fi
    # remove any downloaded debs matching mailspring-*.deb in ROOT
    shopt -s nullglob
    debs=("$ROOT"/mailspring-*.deb)
    shopt -u nullglob
    if [ ${#debs[@]} -gt 0 ]; then
        for d in "${debs[@]}"; do
            rm -v "$d"
        done
    else
        echo "- No downloaded .deb files found in $ROOT"
    fi
    echo "🧹 Removal complete."
    exit 0
fi

# Detect system architecture and map to AppImage naming when needed
UNAME_M=$(uname -m)
case "$UNAME_M" in
    x86_64|amd64) ARCH_STR="x86_64" ; DEB_ARCH="amd64" ;;
    aarch64|arm64) ARCH_STR="aarch64" ; DEB_ARCH="arm64" ;;
    armv7l|armv7) ARCH_STR="armv7" ; DEB_ARCH="armhf" ;;
    *) ARCH_STR="$UNAME_M" ; DEB_ARCH="$UNAME_M" ;;
esac

# 🔍 Obtain the latest version from GitHub API if not set
if [ -z "$VERSION" ]; then
    echo "📡 Fetching latest Mailspring version from GitHub..."
    if [ "$VERBOSE" = true ]; then
        VERSION=$(curl -s https://api.github.com/repos/Foundry376/Mailspring/releases/latest \
                  | grep -Po '"tag_name": "\K.*?(?=")')
    else
        VERSION=$(curl -s https://api.github.com/repos/Foundry376/Mailspring/releases/latest \
                  | grep -Po '"tag_name": "\K.*?(?=")') 2>/dev/null
    fi

    if [ -z "$VERSION" ]; then
        echo "❌ Error: Failed to retrieve version from GitHub API."
        exit 1
    fi
    echo "🔢 Found version: $VERSION"
    echo ""
fi

VERSION_DIR="$ROOT/$VERSION"
APPDIR="$VERSION_DIR/$APP.AppDir"
DEB_FILE="$ROOT/${APP}-${VERSION}-${DEB_ARCH}.deb"

# Find actual tar binary path to avoid shell aliases/functions that modify behaviour
TAR_BIN=$(type -P tar 2>/dev/null || command -v tar 2>/dev/null || echo /usr/bin/tar)

# helper to extract compressed data archives robustly
_extract_tar() {
    f="$1"
    case "$f" in
        *.xz) "$TAR_BIN" -xJf "$f" ;;
        *.gz) "$TAR_BIN" -xzf "$f" ;;
        *.bz2) "$TAR_BIN" -xjf "$f" ;;
        *) "$TAR_BIN" -xf "$f" ;;
    esac
}

mkdir -p "$VERSION_DIR"
cd "$VERSION_DIR" || exit 1

# ⚙️ Check for system appimagetool; otherwise download a local copy
if command -v appimagetool &>/dev/null; then
    APPIMAGETOOL="appimagetool"
    echo "✅ Using system appimagetool"
else
    APPIMAGETOOL="$ROOT/appimagetool"
    if [ ! -x "$APPIMAGETOOL" ]; then
        echo "⬇️ Downloading local copy of appimagetool..."
        if [ "$VERBOSE" = true ]; then
        wget -O "$APPIMAGETOOL" \
            "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${ARCH_STR}.AppImage"
        else
            wget -q -O "$APPIMAGETOOL" \
                "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$(uname -m).AppImage"
        fi
        chmod a+x "$APPIMAGETOOL"
    else
        echo "✅ Using existing local copy of appimagetool"
    fi
fi

echo ""

# ⬇️ Download .deb if not present
if [ ! -f "$DEB_FILE" ]; then
    echo "⬇️ Downloading Mailspring .deb package (version $VERSION)..."
    if [ "$VERBOSE" = true ]; then
        wget -O "$DEB_FILE" \
            "https://github.com/Foundry376/Mailspring/releases/download/${VERSION}/mailspring-${VERSION}-${DEB_ARCH}.deb"
    else
        wget -q -O "$DEB_FILE" \
            "https://github.com/Foundry376/Mailspring/releases/download/${VERSION}/mailspring-${VERSION}-${DEB_ARCH}.deb"
    fi
    echo ""
fi

# 📦 Extract .deb if not already extracted
if [ ! -f "$VERSION_DIR/debian-binary" ]; then
    if [ "$VERBOSE" = true ]; then
        ar x "$DEB_FILE"
        # extract any data.tar.* (could be .xz, .gz, .bz2), pick first match
        shopt -s nullglob
        data_tar=("$VERSION_DIR"/data.tar.*)
        shopt -u nullglob
        if [ ${#data_tar[@]} -gt 0 ]; then
            _extract_tar "${data_tar[0]}"
        else
            echo "❌ Error: data.tar.* not found inside the deb package"
            exit 1
        fi
    else
        ar x "$DEB_FILE" 2>/dev/null
        shopt -s nullglob
        data_tar=("$VERSION_DIR"/data.tar.*)
        shopt -u nullglob
        if [ ${#data_tar[@]} -gt 0 ]; then
            _extract_tar "${data_tar[0]}" 2>/dev/null
        else
            echo "❌ Error: data.tar.* not found inside the deb package"
            exit 1
        fi
    fi
    echo ""
fi

# 🛠️ Build AppImage (always, no check if it already exists)
echo "🔧 Building AppImage for $APP ($VERSION)..."
[ -d "$APPDIR" ] && rm -rf "$APPDIR"
mkdir -p "$APPDIR"

# Create AppRun
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/sh
APP=mailspring
HERE="$(dirname "$(readlink -f "${0}")")"
exec "${HERE}/$APP/$APP" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Copy necessary files (icons, .desktop, and usr/share/mailspring directory)
if [ "$VERBOSE" = true ]; then
    cp -rv "$VERSION_DIR/usr/share/mailspring" "$APPDIR/mailspring"
    cp -v "$VERSION_DIR/usr/share/applications/"*.desktop "$APPDIR/$APP.desktop"
    cp -v "$VERSION_DIR/usr/share/icons/hicolor/256x256/apps/"*.png "$APPDIR/$APP.png"
else
    cp -r "$VERSION_DIR/usr/share/mailspring" "$APPDIR/mailspring"
    cp "$VERSION_DIR/usr/share/applications/"*.desktop "$APPDIR/$APP.desktop" 2>/dev/null
    cp "$VERSION_DIR/usr/share/icons/hicolor/256x256/apps/"*.png "$APPDIR/$APP.png" 2>/dev/null
fi

echo ""

cd "$VERSION_DIR" || exit 1

# Run appimagetool
if [ "$VERBOSE" = true ]; then
    ARCH="$ARCH_STR" "$APPIMAGETOOL" -n --verbose "$APPDIR" \
        "$ROOT/$APP-$VERSION-${ARCH_STR}.AppImage"
else
    ARCH="$ARCH_STR" "$APPIMAGETOOL" -n "$APPDIR" \
        "$ROOT/$APP-$VERSION-${ARCH_STR}.AppImage" > /dev/null 2>&1
fi

echo ""

# 🏷️ Rename AppImage to remove version
if [ -f "$ROOT/$APP-$VERSION-${ARCH_STR}.AppImage" ]; then
    mv -v "$ROOT/$APP-$VERSION-${ARCH_STR}.AppImage" "$ROOT/$APP.AppImage"
    echo ""
fi

# 📌 Save icon next to AppImage for .desktop file
cp "$VERSION_DIR/usr/share/icons/hicolor/256x256/apps/"*.png "$ROOT/$APP.png" 2>/dev/null

# 🧹 Clean up .deb file
if [ -f "$DEB_FILE" ]; then
    echo "🧹 Removing downloaded .deb package"
    rm -v "$DEB_FILE"
    echo ""
fi

# 🧹 Clean up temporary version directory
if [ -d "$VERSION_DIR" ]; then
    echo "🧹 Removing temporary directory $VERSION_DIR"
    rm -rf "$VERSION_DIR"
    echo ""
fi

echo "✅ AppImage for $APP ($VERSION) is ready at: $ROOT/$APP.AppImage"

# 🏁 Create .desktop file (applications)
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"
DESKTOP_FILE="$DESKTOP_DIR/$APP.desktop"

cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Mailspring
Comment=Modern mail client built as AppImage
Exec=$ROOT/$APP.AppImage %U
Icon=$ROOT/$APP.png
Terminal=false
Categories=Network;Email;
EOF

echo "✅ .desktop file created: $DESKTOP_FILE"

# 🚀 Optional: Create autostart .desktop with -b if requested
if [ "$AUTOSTART_BG" = true ]; then
  AUTOSTART_DIR="$HOME/.config/autostart"
  mkdir -p "$AUTOSTART_DIR"
  AUTOSTART_FILE="$AUTOSTART_DIR/${APP}-background.desktop"

  cat > "$AUTOSTART_FILE" << EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Mailspring (Background)
Comment=Automatically start Mailspring in background on login
Exec=$ROOT/$APP.AppImage -b
Icon=$ROOT/$APP.png
Terminal=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=GNOME;KDE;XFCE;LXQt;LXDE;MATE;Cinnamon;Unity;
Categories=Network;Email;
MimeType=x-scheme-handler/mailto;x-scheme-handler/mailspring;
EOF

    echo "✅ Autostart entry created: $AUTOSTART_FILE"
fi

