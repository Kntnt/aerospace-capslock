#!/bin/bash
# Install the configuration and its helper, keeping a copy of replaced files.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
config_file="$HOME/.aerospace.toml"
support_dir="$HOME/.config/aerospace"
alternate_config="${XDG_CONFIG_HOME:-$HOME/.config}/aerospace/aerospace.toml"

if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --dry-run ) ]]; then
    echo "Usage: ./install.sh [--dry-run]" >&2
    exit 2
fi
if [[ "$(uname -s)" != Darwin ]]; then
    echo "This configuration and its helper require macOS." >&2
    exit 1
fi
if [[ -e "$alternate_config" || -L "$alternate_config" ]]; then
    echo "AeroSpace also has a configuration at $alternate_config." >&2
    echo "Keep one config location. Move that file aside before installing this one." >&2
    exit 1
fi
if [[ -L "$config_file" ]]; then
    echo "$config_file is a symlink. Update your dotfiles source manually instead of replacing the link." >&2
    exit 1
fi
if [[ "${1:-}" == --dry-run ]]; then
    echo "Would build the Swift helper and install:"
    echo "  $config_file"
    echo "  $support_dir/bin/aerospace-shortcuts"
    echo "Existing files would be backed up under $support_dir/backups/."
    exit 0
fi

"$project_dir/build.sh"

backup_dir="$support_dir/backups/$(date +%Y%m%d-%H%M%S)-$$"
for existing in "$config_file" "$support_dir/bin/aerospace-shortcuts"; do
    if [[ -e "$existing" ]]; then
        mkdir -p "$backup_dir"
        cp -p "$existing" "$backup_dir/$(basename "$existing")"
    fi
done
mkdir -p "$support_dir/bin" "$HOME/Library/Logs"
install -m 755 "$project_dir/bin/aerospace-shortcuts" "$support_dir/bin/aerospace-shortcuts"
install -m 644 "$project_dir/aerospace.toml" "$config_file"

echo "Installed the configuration and helper."
if [[ -d "$backup_dir" ]]; then
    echo "Backup: $backup_dir"
fi
echo "In Hyperkey, remap Caps Lock and turn OFF 'Include shift in hyper key'."
echo "Then start AeroSpace, or quit and reopen it if it is already running."
