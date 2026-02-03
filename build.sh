#!/bin/bash

# Build script for Nolon

# Ensure Xcode tools are selected
if ! xcode-select -p &> /dev/null; then
    echo "Error: Xcode tools not found. Please install Xcode."
    exit 1
fi

if [[ -f ".gitmodules" ]]; then
    missing_submodule=0
    for path in libs/CodexBar libs/SKProcessRunner libs/agent-skills libs/codex libs/oh-my-opencode libs/opencode; do
        if [[ ! -e "${path}/.git" ]]; then
            echo "Error: submodule '${path}' is not populated."
            missing_submodule=1
        fi
    done

    if [[ "${missing_submodule}" == "1" ]]; then
        echo "Hint: run 'git submodule update --init --recursive' and try again."
        exit 1
    fi
fi

echo "🚀 Building Nolon..."

XCODEBUILD_ARGS=(
    -project nolon.xcodeproj
    -scheme nolon
    -configuration Release
    -destination 'platform=macOS'
)

# Optional: avoid hitting the network / updating SwiftPM dependencies.
# Useful when you already have checkouts in DerivedData and want a deterministic build.
if [[ "${NO_SPM_UPDATE:-0}" == "1" ]]; then
    XCODEBUILD_ARGS+=(-disableAutomaticPackageResolution)
fi

# Optional: customize DerivedData location (e.g. /tmp/nolonDerivedData).
if [[ -n "${DERIVED_DATA_PATH:-}" ]]; then
    XCODEBUILD_ARGS+=(-derivedDataPath "${DERIVED_DATA_PATH}")
fi

if [[ "${SKIP_CLEAN:-0}" != "1" ]]; then
    XCODEBUILD_ARGS+=(clean)
fi

XCODEBUILD_ARGS+=(build)

xcodebuild "${XCODEBUILD_ARGS[@]}"

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
else
    echo "❌ Build failed."
    exit 1
fi
