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
echo "   Building Catscale (iOS 18+ / iPadOS 18+)"
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

embed_mach_o_entitlements() {
  local target_app="$1"
  local ent_file="$SCRIPT_DIR/Catscale.entitlements"
  local bin_path="$target_app/Catscale"

  if [ ! -f "$bin_path" ]; then
    bin_path=$(find "$target_app" -maxdepth 1 -type f -perm +111 2>/dev/null | head -n 1 || true)
  fi

  if [ -f "$bin_path" ] && [ -f "$ent_file" ]; then
    echo "🔑 Injecting entitlements into Mach-O executable: $bin_path"
    if command -v ldid &>/dev/null; then
      echo "Running: ldid -S$ent_file $bin_path"
      ldid -S"$ent_file" "$bin_path" || true
    elif command -v codesign &>/dev/null; then
      echo "Running: codesign -s - --force --entitlements $ent_file $bin_path"
      codesign -s - --force --entitlements "$ent_file" "$bin_path" || true
    fi
  else
    echo "⚠️ Mach-O executable or entitlements file not found: bin=$bin_path ent=$ent_file"
  fi
}

merge_info_plist() {
  local target_app="$1"
  local src_info="$SCRIPT_DIR/Catscale-Info.plist"
  if [ -d "$target_app" ] && [ -f "$src_info" ]; then
    echo "📋 Resolving bundle variables and enforcing complete Info.plist metadata..."
    python3 - "$target_app" "$src_info" << 'EOF'
import plistlib, os, sys

target_app = sys.argv[1]
src_path = sys.argv[2]
dest_path = os.path.join(target_app, 'Info.plist')

dest = {}
if os.path.exists(dest_path):
    try:
        with open(dest_path, 'rb') as f:
            dest = plistlib.load(f)
    except Exception as e:
        print("Warning reading dest plist:", e)
        dest = {}

try:
    with open(src_path, 'rb') as f:
        src = plistlib.load(f)
    dest.update(src)

    replacements = {
        '$(PRODUCT_NAME)': 'Catscale',
        '$(PRODUCT_BUNDLE_IDENTIFIER)': 'com.catscale.app',
        '$(EXECUTABLE_NAME)': 'Catscale',
        '$(TARGET_NAME)': 'Catscale',
        '$(MARKETING_VERSION)': '0.0.2',
        '$(CURRENT_PROJECT_VERSION)': '2',
        '$(DEVELOPMENT_LANGUAGE)': 'en',
    }

    for k, v in list(dest.items()):
        if isinstance(v, str):
            for var, val in replacements.items():
                if var in v:
                    v = v.replace(var, val)
            dest[k] = v

    # Hard-enforce exact values
    dest['CFBundleName'] = 'Catscale'
    dest['CFBundleDisplayName'] = 'Catscale'
    dest['CFBundleExecutable'] = 'Catscale'
    dest['CFBundleIdentifier'] = 'com.catscale.app'
    dest['CFBundlePackageType'] = 'APPL'
    dest['CFBundleShortVersionString'] = '0.0.2'
    dest['CFBundleVersion'] = '2'
    dest['CFBundleDevelopmentRegion'] = 'en'
    dest['LSRequiresIPhoneOS'] = True
    dest['UIDeviceFamily'] = [1, 2]
    dest['NSPhotoLibraryUsageDescription'] = 'Catscale requires access to your photo library to select and upscale images.'
    dest['NSPhotoLibraryAddUsageDescription'] = 'Catscale requires permission to save upscaled high-resolution photos to your library.'
    dest['UIFileSharingEnabled'] = True
    dest['LSSupportsOpeningDocumentsInPlace'] = True
    dest['UIApplicationSceneManifest'] = {'UIApplicationSupportsMultipleScenes': True}
    dest['UILaunchScreen'] = {}
    dest['UISupportedInterfaceOrientations'] = [
        'UIInterfaceOrientationPortrait',
        'UIInterfaceOrientationLandscapeLeft',
        'UIInterfaceOrientationLandscapeRight',
    ]
    dest['UISupportedInterfaceOrientations~ipad'] = [
        'UIInterfaceOrientationPortrait',
        'UIInterfaceOrientationPortraitUpsideDown',
        'UIInterfaceOrientationLandscapeLeft',
        'UIInterfaceOrientationLandscapeRight',
    ]

    with open(dest_path, 'wb') as f:
        plistlib.dump(dest, f)
    print("✅ Successfully merged and sanitized Info.plist at", dest_path)
except Exception as e:
    print("Error during Info.plist merge:", e)
    sys.exit(1)
EOF
  fi
}

# Determine build tool
if command -v xtool &>/dev/null; then
  echo "🔧 Building via xtool (Cross-platform SwiftPM Darwin toolchain)..."

  xtool dev build

  APP_SOURCE="xtool/Catscale.app"
  if [ -d "$APP_SOURCE" ]; then
    # Merge complete Info.plist
    merge_info_plist "$APP_SOURCE"

    # Inject entitlements for sideloading tools
    cp Catscale.entitlements "$APP_SOURCE/archived-expanded-entitlements.xcent" 2>/dev/null || true
    cp Catscale.entitlements "$APP_SOURCE/Catscale.entitlements" 2>/dev/null || true
    cp Catscale.entitlements "$APP_SOURCE/Entitlements.plist" 2>/dev/null || true

    # Strip existing signatures and inject binary entitlements
    strip_code_signatures "$APP_SOURCE"
    embed_mach_o_entitlements "$APP_SOURCE"

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

elif command -v xcodebuild &>/dev/null; then
  echo "🔧 Building via Apple Xcode & XcodeGen..."

  if command -v xcodegen &>/dev/null; then
    echo "⚙️ Generating Xcode project via XcodeGen..."
    xcodegen generate
  fi

  if [ -f "Catscale.xcodeproj/project.pbxproj" ]; then
    echo "🚀 Compiling via xcodebuild..."
    xcodebuild build \
      -project Catscale.xcodeproj \
      -scheme Catscale \
      -configuration Release \
      -destination 'generic/platform=iOS' \
      -derivedDataPath build/DerivedData \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO \
      CODE_SIGN_IDENTITY=""

    APP_PATH=$(find build/DerivedData -path "*/Build/Products/Release-iphoneos/Catscale.app" -type d 2>/dev/null | head -n 1)
    if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
      APP_PATH=$(find build/DerivedData -name "Catscale.app" -type d 2>/dev/null | head -n 1)
    fi

    if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
      echo "❌ Failed to locate compiled Catscale.app in DerivedData"
      exit 1
    fi

    echo "📱 Found compiled app bundle: $APP_PATH"

    # Merge complete Info.plist
    merge_info_plist "$APP_PATH"

    # Inject entitlements and strip signatures
    cp Catscale.entitlements "$APP_PATH/archived-expanded-entitlements.xcent" 2>/dev/null || true
    cp Catscale.entitlements "$APP_PATH/Catscale.entitlements" 2>/dev/null || true
    cp Catscale.entitlements "$APP_PATH/Entitlements.plist" 2>/dev/null || true
    strip_code_signatures "$APP_PATH"
    embed_mach_o_entitlements "$APP_PATH"

    rm -rf "$OUTPUT_DIR/Catscale.app"
    cp -R "$APP_PATH" "$OUTPUT_DIR/"

    if [ "$BUILD_IPA" = true ]; then
      echo "📦 Packaging clean unsigned IPA..."
      mkdir -p "$OUTPUT_DIR/Payload"
      cp -R "$APP_PATH" "$OUTPUT_DIR/Payload/"
      cd "$OUTPUT_DIR"
      rm -f "$IPA_NAME"
      zip -q -r -y "$IPA_NAME" Payload
      rm -rf Payload
      cd "$SCRIPT_DIR"
    fi
  else
    echo "❌ Error: Catscale.xcodeproj not found. Please install xcodegen (brew install xcodegen)."
    exit 1
  fi

elif command -v swift &>/dev/null; then
  echo "🔧 Building via SwiftPM & Apple Toolchain..."

  SWIFT_FLAGS=("-c" "release" "--triple" "arm64-apple-ios26.0")
  if command -v xcrun &>/dev/null; then
    IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)
    if [ -n "$IOS_SDK" ] && [ -d "$IOS_SDK" ]; then
      echo "📱 Detected iOS SDK: $IOS_SDK"
      SWIFT_FLAGS=("--sdk" "$IOS_SDK" "-c" "release" "--triple" "arm64-apple-ios26.0")
    fi
  fi

  swift build "${SWIFT_FLAGS[@]}"

  APP_DIR="$OUTPUT_DIR/Catscale.app"
  rm -rf "$APP_DIR"
  mkdir -p "$APP_DIR"

  BIN_PATH=$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)
  if [ -f "$BIN_PATH/Catscale" ]; then
    cp "$BIN_PATH/Catscale" "$APP_DIR/"
  fi

  # Merge complete Info.plist
  merge_info_plist "$APP_DIR"

  # Copy resource bundles and compiled models
  if [ -d "$BIN_PATH/Catscale_Catscale.bundle" ]; then
    cp -R "$BIN_PATH/Catscale_Catscale.bundle" "$APP_DIR/"
  fi
  if [ -d "Sources/Catscale/Resources" ]; then
    cp -R Sources/Catscale/Resources/* "$APP_DIR/" 2>/dev/null || true
  fi

  # Compile any .mlmodel to .mlmodelc if xcrun coremlc is available
  if command -v xcrun &>/dev/null; then
    for m in "$APP_DIR"/*.mlmodel; do
      if [ -f "$m" ]; then
        xcrun coremlc compile "$m" "$APP_DIR" 2>/dev/null || true
      fi
    done
  fi

  # Inject entitlements and strip signatures
  cp Catscale.entitlements "$APP_DIR/archived-expanded-entitlements.xcent" 2>/dev/null || true
  cp Catscale.entitlements "$APP_DIR/Catscale.entitlements" 2>/dev/null || true
  cp Catscale.entitlements "$APP_DIR/Entitlements.plist" 2>/dev/null || true
  strip_code_signatures "$APP_DIR"
  embed_mach_o_entitlements "$APP_DIR"

  if [ "$BUILD_IPA" = true ]; then
    echo "📦 Packaging clean unsigned IPA..."
    mkdir -p "$OUTPUT_DIR/Payload"
    cp -R "$APP_DIR" "$OUTPUT_DIR/Payload/"
    cd "$OUTPUT_DIR"
    rm -f "$IPA_NAME"
    zip -q -r -y "$IPA_NAME" Payload
    rm -rf Payload
    cd "$SCRIPT_DIR"
  fi
else
  echo "❌ Error: Neither 'xtool', 'xcodebuild', nor 'swift' was found in PATH."
  echo "Please install xtool (https://github.com/xtool-org/xtool) or Xcode."
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
