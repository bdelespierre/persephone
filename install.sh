#!/usr/bin/env bash
#
# install.sh - Quick installer for persephone
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/bdelespierre/persephone/master/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/bdelespierre/persephone/master/install.sh | PREFIX=/usr/local bash
#   curl -fsSL https://raw.githubusercontent.com/bdelespierre/persephone/master/install.sh | TAG=v0.1.0 bash
#

set -euo pipefail

info()  { echo -e "\033[0;32m[INFO]\033[0m $*"; }
error() { >&2 echo -e "\033[0;31m[ERROR]\033[0m $*"; }

REPO="bdelespierre/persephone"
TAG="${TAG:-$(curl -fsSL "https://api.github.com/repos/$REPO/tags" | grep -o '"name": *"[^"]*"' | head -1 | cut -d'"' -f4)}"
if [[ -z "$TAG" ]]; then
    error "Failed to fetch latest release tag"
    exit 1
fi
BASE_URL="https://raw.githubusercontent.com/$REPO/$TAG"
PREFIX="${PREFIX:-$HOME/.local}"
BINDIR="$PREFIX/bin"
LIBDIR="$PREFIX/lib/persephone"

# Check dependencies
if ! command -v openssl &>/dev/null; then
    error "openssl is required but not installed"
    exit 1
fi

if ! command -v curl &>/dev/null; then
    error "curl is required but not installed"
    exit 1
fi

# Create directories
mkdir -p "$BINDIR" "$LIBDIR"

# Download files
info "Downloading persephone $TAG to $PREFIX..."

curl -fsSL "$BASE_URL/bin/crypt" -o "$BINDIR/crypt"
curl -fsSL "$BASE_URL/lib/persephone/utils.bash" -o "$LIBDIR/utils.bash"
curl -fsSL "$BASE_URL/lib/persephone/crypt.bash" -o "$LIBDIR/crypt.bash"

chmod +x "$BINDIR/crypt"

info "Installed crypt to $BINDIR/crypt"
info "Installed libs to $LIBDIR/"

# Check if BINDIR is in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BINDIR"; then
    echo
    info "Add $BINDIR to your PATH:"
    echo "  export PATH=\"$BINDIR:\$PATH\""
fi
