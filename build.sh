#!/bin/bash
set -euo pipefail

# Build script for Nolon

# Ensure Xcode tools are selected
if ! xcode-select -p &> /dev/null; then
    echo "Error: Xcode tools not found. Please install Xcode."
    exit 1
fi

if [[ -f ".gitmodules" && "${CHECK_SUBMODULES:-0}" == "1" ]]; then
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

echo "🚀 Running Nolon gate..."

SCHEME="${XCODE_SCHEME:-nolon-app}"
BUILD_CONFIGURATION="${XCODE_CONFIGURATION:-Release}"
TEST_CONFIGURATION="${XCODE_TEST_CONFIGURATION:-Debug}"
RUN_TESTS="${RUN_TESTS:-1}"
DESTINATION="${XCODE_DESTINATION:-platform=macOS}"
TEST_SCOPE="${TEST_SCOPE:-unit}"

XCODEBUILD_ARGS=(
    -project nolon.xcodeproj
    -scheme "${SCHEME}"
    -configuration "${BUILD_CONFIGURATION}"
    -destination "${DESTINATION}"
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

echo "ℹ️ Scheme: ${SCHEME}"
echo "ℹ️ Build configuration: ${BUILD_CONFIGURATION}"
echo "ℹ️ Destination: ${DESTINATION}"

xcodebuild "${XCODEBUILD_ARGS[@]}"
echo "✅ Build succeeded!"

if [[ "${RUN_TESTS}" == "1" ]]; then
    echo "🧪 Running tests..."
    TEST_ARGS=(
        -project nolon.xcodeproj \
        -scheme "${SCHEME}" \
        -configuration "${TEST_CONFIGURATION}" \
        -destination "${DESTINATION}" \
        test
    )

    case "${TEST_SCOPE}" in
        unit)
            TEST_ARGS+=(-only-testing:nolonTests)
            echo "ℹ️ Test scope: unit (nolonTests)"
            ;;
        ui)
            TEST_ARGS+=(-only-testing:nolonUITests)
            echo "ℹ️ Test scope: ui (nolonUITests)"
            ;;
        all)
            echo "ℹ️ Test scope: all"
            ;;
        *)
            echo "❌ Invalid TEST_SCOPE='${TEST_SCOPE}'. Expected: unit | ui | all"
            exit 1
            ;;
    esac

    xcodebuild "${TEST_ARGS[@]}"
    echo "✅ Tests passed! (${TEST_SCOPE})"
else
    echo "⏭️ Tests skipped (RUN_TESTS=${RUN_TESTS})"
fi
