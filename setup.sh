#!/bin/bash
# Download a complete snapshot before running the installer.
set -euo pipefail

setup() (
    if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --dry-run ) ]]; then
        echo "Usage: setup.sh [--dry-run]" >&2
        exit 2
    fi
    if [[ "$(uname -s)" != Darwin ]]; then
        echo "AeroSpace Harmony requires macOS." >&2
        exit 1
    fi
    local download_dir
    download_dir="$(mktemp -d "${TMPDIR:-/tmp}/aerospace-harmony.XXXXXX")"
    # Capture the path now: Bash may discard function locals before an error's EXIT trap.
    # shellcheck disable=SC2064
    trap "rm -rf -- $(printf '%q' "$download_dir")" EXIT
    trap 'exit 130' INT
    trap 'exit 143' HUP TERM
    echo "Downloading AeroSpace Harmony..."
    curl --fail --silent --show-error --location --retry 3 \
        https://github.com/Kntnt/aerospace-harmony/archive/refs/heads/main.tar.gz \
        --output "$download_dir/source.tar.gz"
    mkdir "$download_dir/source"
    tar -xzf "$download_dir/source.tar.gz" --strip-components=1 -C "$download_dir/source"
    /bin/bash "$download_dir/source/install.sh" "$@"
)

setup "$@"
