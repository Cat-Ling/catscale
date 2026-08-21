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

# Determine build tool
if command -v xtool &>/dev/null; then
  echo "🔧 Building via xtool (Cross-platform SwiftPM Darwin toolchain)..."
  
  if [ "$BUILD_IPA" = true ]; then
    xtool dev build --ipa
    
    # Locate generated IPA
    if [ -f "xtool/Catscale.ipa" ]; then
      cp "xtool/Catscale.ipa" "$OUTPUT_DIR/$IPA_NAME"
    fi
  else
    xtool dev build
  fi

  if [ -d "xtool/Catscale.app" ]; then
    cp Catscale.entitlements "xtool/Catscale.app/archived-expanded-entitlements.xcent" 2>/dev/null || true
    cp Catscale.entitlements "xtool/Catscale.app/Catscale.entitlements" 2>/dev/null || true
    cp -R "xtool/Catscale.app" "$OUTPUT_DIR/"
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
  
  if [ "$BUILD_IPA" = true ]; then
    echo "📦 Packaging unsigned IPA..."
    mkdir -p "$OUTPUT_DIR/Payload"
    cp -R "$APP_DIR" "$OUTPUT_DIR/Payload/"
    cd "$OUTPUT_DIR"
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
