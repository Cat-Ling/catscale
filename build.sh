#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Catscale — iOS Build & Packaging Script
# Supports: Linux, macOS, and CI environments
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

OUTPUT_DIR="$SCRIPT_DIR/build_output"
APP_NAME="Catscale"
IPA_NAME="Catscale-unsigned.ipa"
FETCH_MODELS=false
CLEAN_BUILD=false
BUILD_IPA=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --fetch-models)
      FETCH_MODELS=true
      shift
      ;;
    --clean)
      CLEAN_BUILD=true
      shift
      ;;
    --app-only)
      BUILD_IPA=false
      shift
      ;;
    -h|--help)
      echo "Usage: ./build.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --fetch-models   Pre-download all remote AI models before building"
      echo "  --app-only       Build .app bundle without packaging into .ipa"
      echo "  --clean          Clean previous build artifacts before building"
      echo "  -h, --help       Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run './build.sh --help' for usage."
      exit 1
      ;;
  esac
done

echo "🐱 ========================================================"
echo "   Building Catscale (iOS 18+ / macOS 15+)"
echo "============================================================"

# Handle clean
if [ "$CLEAN_BUILD" = true ]; then
  echo "🧹 Cleaning previous build artifacts..."
  rm -rf .build xtool build_output payload Payload *.ipa
fi

mkdir -p "$OUTPUT_DIR"

# Optional Model Pre-fetching (if user wants a fully bundled offline IPA)
if [ "$FETCH_MODELS" = true ]; then
  echo "⬇️ Fetching remote AI models (Real-ESRGAN, Real-CUGAN, SRMD)..."
  RESOURCES_DIR="Sources/Catscale/Resources"
  mkdir -p "$RESOURCES_DIR"

  # Real-ESRGAN UltraSharp from HuggingFace
  if [ ! -f "$RESOURCES_DIR/RealESRGAN-UltraSharp.mlpackage.zip" ]; then
    echo "Downloading Real-ESRGAN UltraSharp..."
    curl -sL --retry 3 -o "$RESOURCES_DIR/RealESRGAN-UltraSharp.mlpackage.zip" \
      "https://huggingface.co/VincentGOURBIN/RealESRGAN-CoreML/resolve/main/RealESRGAN-UltraSharp.mlpackage.zip" || true
  fi

  # Real-CUGAN 2x No Denoise from CatML Release
  if [ ! -f "$RESOURCES_DIR/RealCUGAN-2x-NoDenoise.mlpackage.zip" ]; then
    echo "Downloading Real-CUGAN 2x..."
    curl -sL --retry 3 -o "$RESOURCES_DIR/RealCUGAN-2x-NoDenoise.mlpackage.zip" \
      "https://github.com/Cat-Ling/CatML/releases/download/0.1/RealCUGAN-2x-NoDenoise.mlpackage.zip" || true
  fi

  # SRMD 2x from CatML Release
  if [ ! -f "$RESOURCES_DIR/SRMDNF-2x.mlpackage.zip" ]; then
    echo "Downloading SRMD 2x..."
    curl -sL --retry 3 -o "$RESOURCES_DIR/SRMDNF-2x.mlpackage.zip" \
      "https://github.com/Cat-Ling/CatML/releases/download/0.1/SRMDNF-2x.mlpackage.zip" || true
  fi
fi

strip_code_signatures() {
  local target_app="$1"
  if [ -d "$target_app" ]; then
    echo "🧹 Stripping existing code signatures for clean unsigned sideloading..."

    # 1. Native Darwin codesign removal if available
    if command -v codesign &>/dev/null; then
      codesign --remove-signature "$target_app" 2>/dev/null || true
      find "$target_app" \( -name "*.dylib" -o -name "*.framework" \) -print0 2>/dev/null | \
        while IFS= read -r -d '' f; do
          codesign --remove-signature "$f" 2>/dev/null || true
        done
    fi

    # 2. Recursively delete all _CodeSignature directories
    find "$target_app" -name "_CodeSignature" -type d -exec rm -rf {} + 2>/dev/null || true

    # 3. Remove any embedded provisioning profiles
    find "$target_app" -name "embedded.mobileprovision" -type f -delete 2>/dev/null || true
  fi
}

# Determine build tool
if command -v xtool &>/dev/null; then
  echo "🔧 Building via xtool (Cross-platform SwiftPM Darwin toolchain)..."

  xtool dev build

  APP_SOURCE="xtool/Catscale.app"
  if [ -d "$APP_SOURCE" ]; then
    # Inject entitlements for sideloading tools
    cp Catscale.entitlements "$APP_SOURCE/archived-expanded-entitlements.xcent" 2>/dev/null || true
    cp Catscale.entitlements "$APP_SOURCE/Catscale.entitlements" 2>/dev/null || true

    # Strip existing signatures
    strip_code_signatures "$APP_SOURCE"

    # Copy clean .app to build_output
    rm -rf "$OUTPUT_DIR/Catscale.app"
    cp -R "$APP_SOURCE" "$OUTPUT_DIR/"

    # Package clean unsigned IPA
    if [ "$BUILD_IPA" = true ]; then
      echo "📦 Packaging clean unsigned IPA..."
      mkdir -p "$OUTPUT_DIR/Payload"
      cp -R "$APP_SOURCE" "$OUTPUT_DIR/Payload/"
      cd "$OUTPUT_DIR"
      rm -f "$IPA_NAME"
      zip -q -r -y "$IPA_NAME" Payload
      rm -rf Payload
      cd "$SCRIPT_DIR"
    fi
  fi
  cp Catscale.entitlements "$OUTPUT_DIR/" 2>/dev/null || true

elif command -v swift &>/dev/null; then
  echo "🔧 Building via SwiftPM..."
  swift build -c release --triple arm64-apple-ios18.0

  APP_DIR="$OUTPUT_DIR/Catscale.app"
  mkdir -p "$APP_DIR"

  BIN_PATH=$(swift build -c release --triple arm64-apple-ios18.0 --show-bin-path)
  if [ -f "$BIN_PATH/Catscale" ]; then
    cp "$BIN_PATH/Catscale" "$APP_DIR/"
    cp Catscale-Info.plist "$APP_DIR/Info.plist"
  fi

  # Inject entitlements and strip signatures
  cp Catscale.entitlements "$APP_DIR/archived-expanded-entitlements.xcent" 2>/dev/null || true
  cp Catscale.entitlements "$APP_DIR/Catscale.entitlements" 2>/dev/null || true
  strip_code_signatures "$APP_DIR"

  if [ "$BUILD_IPA" = true ]; then
    echo "📦 Packaging unsigned IPA..."
    mkdir -p "$OUTPUT_DIR/Payload"
    cp -R "$APP_DIR" "$OUTPUT_DIR/Payload/"
    cd "$OUTPUT_DIR"
    rm -f "$IPA_NAME"
    zip -q -r -y "$IPA_NAME" Payload
    rm -rf Payload
    cd "$SCRIPT_DIR"
  fi
else
  echo "❌ Error: Neither 'xtool' nor 'swift' was found in PATH."
  echo "Please install xtool (https://github.com/xtool-org/xtool) or Swift toolchain."
  exit 1
fi

echo ""
echo "🎉 Build finished successfully!"
echo "============================================================"
if [ -d "$OUTPUT_DIR/Catscale.app" ]; then
  echo "📱 App Bundle: $OUTPUT_DIR/Catscale.app"
fi
if [ -f "$OUTPUT_DIR/$IPA_NAME" ]; then
  IPA_SIZE=$(ls -lh "$OUTPUT_DIR/$IPA_NAME" | awk '{print $5}')
  echo "📦 Unsigned IPA: $OUTPUT_DIR/$IPA_NAME ($IPA_SIZE)"
fi
echo "============================================================"
