#!/bin/bash
set -e

VERSION="${1:-0.2.0}"
OUTPUT_DIR="priv/precompiled"

echo "Building precompiled NIFs for version $VERSION"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Clean previous builds
mix clean

# Build the project
echo "Building NIF..."
MIX_ENV=prod mix compile

# Find the compiled .so file
SO_FILE=$(find _build/prod -name "Elixir.Nosnos.so" | head -1)

if [ -z "$SO_FILE" ]; then
  echo "Error: Could not find compiled .so file"
  exit 1
fi

# Get platform triple
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case "$ARCH" in
  x86_64) ARCH_TRIPLE="x86_64" ;;
  aarch64|arm64) ARCH_TRIPLE="aarch64" ;;
  armv7l) ARCH_TRIPLE="arm" ;;
  i686|i386) ARCH_TRIPLE="x86" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux)
    # Detect libc type
    if ldd --version 2>&1 | grep -q musl; then
      ABI="musl"
    else
      ABI="gnu"
    fi
    OS_TRIPLE="linux"
    EXT="so"
    ;;
  darwin)
    OS_TRIPLE="macos"
    ABI="none"
    EXT="so"
    ;;
  freebsd)
    OS_TRIPLE="freebsd"
    ABI="none"
    EXT="so"
    ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

TRIPLE="${ARCH_TRIPLE}-${OS_TRIPLE}-${ABI}"
OUTPUT_FILE="$OUTPUT_DIR/nosnos.$VERSION.$TRIPLE.$EXT"

# Copy the compiled file
cp "$SO_FILE" "$OUTPUT_FILE"

# Generate SHA256 hash
SHASUM=$(shasum -a 256 "$OUTPUT_FILE" | awk '{print $1}')

echo ""
echo "Build successful!"
echo "Triple: $TRIPLE"
echo "File: $OUTPUT_FILE"
echo "SHA256: $SHASUM"
echo ""
echo "Add this to your @shasum in mix.exs:"
echo "\"$TRIPLE\": \"$SHASUM\","
