#!/usr/bin/env bash
# Downloads a Gentoo stage3 tarball and makes it available for a FROM
# scratch Docker image to use.
#
# Usage: fetch-gentoo.sh <ARCH>
#
#  ARCH: amd64, arm64

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# curl https://qa-reports.gentoo.org/output/service-keys.gpg | sha512sum | awk '{ print $1 }'
SIGNATURE_FILE_HASH="21d1c6ccd5c3e82ce4ec2fe4509e072bc1e47d4f16628274d2b508e2d6e111ed0b3b5f7f542ad29d4f58fc0ff475b0d423322de3cad54c0056bf774fed3dffb0"

info() {
  echo -e "\033[1;34m[INFO]\033[0m" "$@"
}


ARCH="${1:-}"
if [[ -z "$ARCH" ]] || ! [[ "$ARCH" =~ ^(arm64|amd64)$ ]]; then
  echo "Usage: $(basename "$0") <ARCH>"
  echo
  echo "  ARCH: amd64, arm64"
  exit
fi

# Download the Gentoo signing keys, comparing them to the time of this
# script's writing (avoids us having to vendor them).
gentooKeys="$(mktemp)"
wget -O "$gentooKeys" https://qa-reports.gentoo.org/output/service-keys.gpg
if [[ "$(sha512sum "$gentooKeys" | awk '{ print $1 }')" != "$SIGNATURE_FILE_HASH" ]]; then
  echo "Gentoo signing keys did not match expected hash" >&2
  exit 1
fi

export GNUPGHOME=$(mktemp -d)
gpg --import "$gentooKeys"
info "Imported Gentoo signing keys successfully"

DOWNLOAD_DIR=$(mktemp -d)

wget -q -O "$DOWNLOAD_DIR/latest-version.txt" \
  "https://distfiles.gentoo.org/releases/$ARCH/autobuilds/latest-stage3-$ARCH-openrc.txt"
gpg --verify "$DOWNLOAD_DIR/latest-version.txt"

GENTOO_VERSION=$(grep "stage3-$ARCH-openrc" "$DOWNLOAD_DIR/latest-version.txt" | awk -F '/' '{ print $1 }')
info "Using Gentoo stage3 snapshot: $GENTOO_VERSION"

TAR_PATH="$DOWNLOAD_DIR/gentoo-$ARCH.tar.xz"

info "Fetching gentoo archive (ARCH: $ARCH)"
wget --progress=bar --show-progress -O "$TAR_PATH" \
  "https://distfiles.gentoo.org/releases/$ARCH/autobuilds/$GENTOO_VERSION/stage3-$ARCH-openrc-$GENTOO_VERSION.tar.xz"
wget --progress=bar --show-progress -O "$TAR_PATH.asc" \
  "https://distfiles.gentoo.org/releases/$ARCH/autobuilds/$GENTOO_VERSION/stage3-$ARCH-openrc-$GENTOO_VERSION.tar.xz.asc"
info "Download successfully"

gpg --verify "$TAR_PATH.asc"
info "Successfully validated downloaded archive"

DECOMPRESSED_PATH="$SCRIPT_DIR/../.gentoo-sources/$ARCH.tar"
mkdir -p "$(dirname "$DECOMPRESSED_PATH")"
rm -f "$DECOMPRESSED_PATH" || true

info "Storing Gentoo tar at $DECOMPRESSED_PATH"
xz --decompress --stdout "$TAR_PATH" >"$DECOMPRESSED_PATH"
rm -f "$TAR_PATH"{,.asc}