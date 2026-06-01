#!/bin/bash
# Downloads the bundled SmolLM2-135M model for inclusion in the app bundle.
# Run this script once before building to include the base LLM model.
#
# Usage: ./Scripts/download_bundled_model.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$PROJECT_DIR/Jarvis"
MODEL_FILENAME="SmolLM2-135M-Instruct-Q4_K_M.gguf"
MODEL_PATH="$RESOURCES_DIR/$MODEL_FILENAME"
MODEL_URL="https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF/resolve/main/$MODEL_FILENAME"

echo "=== Jarvis Bundled Model Downloader ==="
echo ""

if [ -f "$MODEL_PATH" ]; then
    SIZE=$(du -h "$MODEL_PATH" | cut -f1)
    echo "✅ Model already exists: $MODEL_PATH ($SIZE)"
    echo "   Delete it first if you want to re-download."
    exit 0
fi

echo "📥 Downloading $MODEL_FILENAME..."
echo "   URL: $MODEL_URL"
echo "   Destination: $MODEL_PATH"
echo ""

# Use curl with progress bar and resume support
curl -L --progress-bar --retry 3 --retry-delay 5 \
    -C - \
    -o "$MODEL_PATH" \
    "$MODEL_URL"

if [ -f "$MODEL_PATH" ]; then
    SIZE=$(du -h "$MODEL_PATH" | cut -f1)
    echo ""
    echo "✅ Download complete! ($SIZE)"
    echo ""
    echo "Next steps:"
    echo "  1. Open Jarvis.xcodeproj in Xcode"
    echo "  2. Drag '$MODEL_FILENAME' into the Jarvis target"
    echo "  3. Ensure 'Copy items if needed' is unchecked (file is already in place)"
    echo "  4. Ensure it's added to the Jarvis target's 'Copy Bundle Resources' phase"
    echo "  5. Build and run!"
else
    echo "❌ Download failed!"
    exit 1
fi
