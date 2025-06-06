#!/bin/bash

# ========================================================
#  Script for building Mailspring AppImage
#  Author: Barko
#  Contributor: SimOne 😊
#  Source/Idea: https://github.com/zydou/Mailspring-Linux
#  License: MIT License
#  Description: This script downloads, extracts, and builds
#  an AppImage for the Mailspring application. Everything
#  is executed in the current working directory of the
#  user. Use the --verbose flag to show full command output;
#  otherwise, only high-level progress messages are shown.
# ========================================================

# Check if --verbose flag was provided
VERBOSE=false
if [ "$1" = "--verbose" ]; then
    VERBOSE=true
    shift
fi

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

VERSION_DIR="${ROOT:?}/$VERSION"
APPDIR="$VERSION_DIR/$APP.AppDir"
DEB_FILE="$ROOT/${APP}-${VERSION}-amd64.deb"

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
                "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$(uname -m).AppImage"
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
            "https://github.com/Foundry376/Mailspring/releases/download/${VERSION}/mailspring-${VERSION}-amd64.deb"
    else
        wget -q -O "$DEB_FILE" \
            "https://github.com/Foundry376/Mailspring/releases/download/${VERSION}/mailspring-${VERSION}-amd64.deb"
    fi
    echo ""
fi

# 📦 Extract .deb if not already extracted
if [ ! -f "$VERSION_DIR/debian-binary" ]; then
    if [ "$VERBOSE" = true ]; then
        ar x "$DEB_FILE"
        tar xvf "$VERSION_DIR"/data.tar.*
    else
        ar x "$DEB_FILE" 2>/dev/null
        tar xf "$VERSION_DIR"/data.tar.* 2>/dev/null
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
    ARCH=x86_64 "$APPIMAGETOOL" -n --verbose "$APPDIR" \
        "$ROOT/$APP-$VERSION-amd64.AppImage"
else
    ARCH=x86_64 "$APPIMAGETOOL" -n "$APPDIR" \
        "$ROOT/$APP-$VERSION-amd64.AppImage" > /dev/null 2>&1
fi
echo ""

# 🏷️ Rename AppImage to remove version
if [ -f "$ROOT/$APP-$VERSION-amd64.AppImage" ]; then
    mv -v "$ROOT/$APP-$VERSION-amd64.AppImage" "$ROOT/$APP.AppImage"
    echo ""
fi

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

