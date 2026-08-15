#!/bin/bash

set -euo pipefail

readonly BLACKOUT_VERSION="1.1.1"
readonly BLACKOUT_SHA256="82e4aae7f0f0cde1b60649549eba6918bdabef7ada225c508cf593dc21e10ce7"
readonly DOWNLOAD_URL="https://github.com/norgera/Blackout/releases/download/v${BLACKOUT_VERSION}/Blackout.dmg"
readonly INSTALL_PATH="/Applications/Blackout.app"

if pgrep -x Blackout >/dev/null 2>&1; then
    echo "Quit Blackout, then run the installer again." >&2
    exit 1
fi

work_directory="$(mktemp -d "${TMPDIR:-/tmp}/blackout-install.XXXXXX")"
readonly work_directory
readonly disk_image="${work_directory}/Blackout.dmg"
readonly mount_point="${work_directory}/mount"
is_mounted=false

cleanup() {
    if [[ "${is_mounted}" == true ]]; then
        hdiutil detach "${mount_point}" -quiet || true
    fi
    rm -rf "${work_directory}"
}
trap cleanup EXIT INT TERM

echo "Downloading Blackout ${BLACKOUT_VERSION}…"
curl --fail --location --silent --show-error \
    "${DOWNLOAD_URL}" \
    --output "${disk_image}"

actual_sha256="$(shasum -a 256 "${disk_image}" | awk '{print $1}')"
if [[ "${actual_sha256}" != "${BLACKOUT_SHA256}" ]]; then
    echo "The downloaded disk image failed checksum verification." >&2
    echo "Expected: ${BLACKOUT_SHA256}" >&2
    echo "Received: ${actual_sha256}" >&2
    exit 1
fi

mkdir "${mount_point}"
hdiutil attach "${disk_image}" \
    -nobrowse \
    -readonly \
    -mountpoint "${mount_point}" \
    -quiet
is_mounted=true

source_app="${mount_point}/Blackout.app"
if [[ ! -d "${source_app}" ]]; then
    echo "Blackout.app was not found in the disk image." >&2
    exit 1
fi

echo "Installing Blackout in /Applications…"
sudo ditto "${source_app}" "${INSTALL_PATH}"
sudo xattr -dr com.apple.quarantine "${INSTALL_PATH}" 2>/dev/null || true

hdiutil detach "${mount_point}" -quiet
is_mounted=false

echo "Blackout ${BLACKOUT_VERSION} was installed successfully."
open "${INSTALL_PATH}"
