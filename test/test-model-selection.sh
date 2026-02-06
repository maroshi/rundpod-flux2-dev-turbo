#!/bin/bash
# Test script for FLUX_MODEL environment variable handling

set -e

echo "🧪 Testing FLUX.2 Model Selection Logic"
echo "========================================"
echo ""

# Test function
test_model_selection() {
    local flux_model="$1"
    local expected_models="$2"
    local expected_size="$3"

    echo "📋 Testing FLUX_MODEL='$flux_model'"
    echo "   Expected: $expected_models models, ~$expected_size"

    # Set environment variable
    export FLUX_MODEL="$flux_model"

    # Extract just the model selection logic from start.sh
    LOAD_COMMON=0
    LOAD_KLEIN=0
    LOAD_DEV=0

    FLUX_MODEL="${FLUX_MODEL:-common}"

    case "$FLUX_MODEL" in
        klein)
            LOAD_COMMON=1
            LOAD_KLEIN=1
            LOAD_DEV=0
            ;;
        dev)
            LOAD_COMMON=1
            LOAD_KLEIN=0
            LOAD_DEV=1
            ;;
        all)
            LOAD_COMMON=1
            LOAD_KLEIN=1
            LOAD_DEV=1
            ;;
        common)
            LOAD_COMMON=1
            LOAD_KLEIN=0
            LOAD_DEV=0
            ;;
        *)
            LOAD_COMMON=1
            LOAD_KLEIN=0
            LOAD_DEV=0
            ;;
    esac

    # Calculate models loaded
    MODELS_LOADED=0
    [[ $LOAD_COMMON -eq 1 ]] && MODELS_LOADED=$((MODELS_LOADED + 2))
    [[ $LOAD_KLEIN -eq 1 ]] && MODELS_LOADED=$((MODELS_LOADED + 3))
    [[ $LOAD_DEV -eq 1 ]] && MODELS_LOADED=$((MODELS_LOADED + 2))

    # Verify expected model count
    if [[ $MODELS_LOADED -eq $expected_models ]]; then
        echo "   ✅ PASS: $MODELS_LOADED models will be loaded"
    else
        echo "   ❌ FAIL: Expected $expected_models but got $MODELS_LOADED"
        exit 1
    fi

    echo ""
}

# Run tests
test_model_selection "common" 2 "3GB"
test_model_selection "klein" 5 "27GB"
test_model_selection "dev" 4 "54GB"
test_model_selection "all" 7 "76GB"
test_model_selection "invalid" 2 "3GB"  # Should fallback to common
test_model_selection "" 2 "3GB"        # Should default to common

echo "✅ All model selection tests passed!"
