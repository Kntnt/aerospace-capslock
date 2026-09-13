#!/bin/bash
# Install Harmony without replacing unrelated Ghostty settings.
set -euo pipefail

check_destination() {
    if [[ -L "$1" ]]; then
        echo "$1 is a symlink. Update its dotfiles source manually instead of replacing the link." >&2
        return 1
    fi
    if [[ -e "$1" && ! -f "$1" ]]; then
        echo "$1 is not a regular file." >&2
        return 1
    fi
}

ghostty_config_path() {
    local user_dir="$1" xdg_dir="$2" candidate selected=""
    # Ghostty loads all existing files in this order; the last one takes precedence.
    for candidate in "$xdg_dir/ghostty/config.ghostty" "$xdg_dir/ghostty/config" \
        "$user_dir/Library/Application Support/com.mitchellh.ghostty/config.ghostty" \
        "$user_dir/Library/Application Support/com.mitchellh.ghostty/config"; do
        if [[ -e "$candidate" || -L "$candidate" ]]; then selected="$candidate"; fi
    done
    printf '%s\n' "${selected:-$user_dir/Library/Application Support/com.mitchellh.ghostty/config}"
}

install_payload() (
    # Explicit paths also let the filesystem work be tested in an isolated directory.
    local project_dir="$1" user_dir="$2" xdg_dir="$3" has_ghostty="$4" dry_run="${5:-}"
    local config_file="$user_dir/.aerospace.toml" support_dir="$user_dir/.config/aerospace"
    local alternate_config="$xdg_dir/aerospace/aerospace.toml" ghostty_config=""
    local marker="# AeroSpace Harmony: use separate terminal windows."
    local include_line escaped_path stage_dir backup_dir index line
    local sources=("$project_dir/aerospace.toml" "$project_dir/bin/aerospace-shortcuts")
    local destinations=("$config_file" "$support_dir/bin/aerospace-shortcuts")
    local modes=(644 755) backup_names=(aerospace.toml aerospace-shortcuts)

    if [[ -e "$alternate_config" || -L "$alternate_config" ]]; then
        echo "AeroSpace also has a configuration at $alternate_config." >&2
        echo "Move that file aside before installing Harmony at $config_file." >&2
        exit 1
    fi
    if [[ "$has_ghostty" == yes ]]; then
        ghostty_config="$(ghostty_config_path "$user_dir" "$xdg_dir")"
        sources+=("$project_dir/ghostty.conf" "")
        destinations+=("$support_dir/ghostty.conf" "$ghostty_config")
        modes+=(644 644)
        backup_names+=(ghostty.conf ghostty-config)
    fi
    for line in "${destinations[@]}"; do check_destination "$line"; done
    if [[ "$dry_run" == --dry-run ]]; then
        echo "Would build and install AeroSpace Harmony:"
        printf '  %s\n' "${destinations[@]}"
        if [[ "$has_ghostty" == yes ]]; then
            echo "Would append one include for Cmd+T = new window, preserving other Ghostty settings."
        else
            echo "Ghostty not found; its configuration would be left alone."
        fi
        echo "Replaced files would be backed up under $support_dir/backups/."
        echo "Would start AeroSpace, or reload it and restart its Escape helper if already running."
        exit 0
    fi

    # Finish compilation and prepare every file before changing the user's configuration.
    "$project_dir/build.sh"
    stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/aerospace-harmony-install.XXXXXX")"
    # Capture the path now: Bash may discard function locals before an error's EXIT trap.
    # shellcheck disable=SC2064
    trap "rm -rf -- $(printf '%q' "$stage_dir")" EXIT
    trap 'exit 130' INT
    trap 'exit 143' HUP TERM
    if [[ -n "$ghostty_config" ]]; then
        escaped_path="${support_dir//\\/\\\\}/ghostty.conf"
        escaped_path="${escaped_path//\"/\\\"}"
        include_line="config-file = \"$escaped_path\""
        # Put our include last: Ghostty processes included files after the parent file.
        # Remove only our own previous lines, so rerunning never adds duplicate includes.
        if [[ -f "$ghostty_config" ]]; then
            while IFS= read -r line || [[ -n "$line" ]]; do
                if [[ "$line" != "$marker" && "$line" != "$include_line" ]]; then
                    printf '%s\n' "$line"
                fi
            done < "$ghostty_config" > "$stage_dir/ghostty-config"
        else
            : > "$stage_dir/ghostty-config"
        fi
        printf '%s\n%s\n' "$marker" "$include_line" >> "$stage_dir/ghostty-config"
        sources[3]="$stage_dir/ghostty-config"
        if [[ -f "$ghostty_config" ]]; then modes[3]="$(/usr/bin/stat -f '%Lp' "$ghostty_config")"; fi
    fi
    for line in "${sources[@]}"; do
        if [[ ! -f "$line" ]]; then echo "Missing installation file: $line" >&2; exit 1; fi
    done
    backup_dir="$support_dir/backups/$(date +%Y%m%d-%H%M%S)-$$"
    for index in "${!destinations[@]}"; do
        if [[ -f "${destinations[$index]}" ]] && ! cmp -s "${sources[$index]}" "${destinations[$index]}"; then
            mkdir -p "$backup_dir"
            cp -p "${destinations[$index]}" "$backup_dir/${backup_names[$index]}"
        fi
    done
    for index in "${!destinations[@]}"; do
        if ! cmp -s "${sources[$index]}" "${destinations[$index]}"; then
            mkdir -p "$(dirname -- "${destinations[$index]}")"
            # Replace through a sibling file so a running helper can finish using its old binary.
            local replacement
            replacement="$(mktemp "${destinations[$index]}.harmony.XXXXXX")"
            if ! install -m "${modes[$index]}" "${sources[$index]}" "$replacement" || \
                ! mv -f "$replacement" "${destinations[$index]}"; then
                rm -f -- "$replacement"
                echo "Installation failed. Existing files are backed up at $backup_dir." >&2
                exit 1
            fi
        fi
    done
    mkdir -p "$user_dir/Library/Logs"
    echo "Installed AeroSpace Harmony and its Escape/app helper."
    if [[ -d "$backup_dir" ]]; then echo "Backup: $backup_dir"; fi
    if [[ -n "$ghostty_config" ]]; then
        echo "Ghostty configured: $ghostty_config"
        echo "In Ghostty, press Cmd+Shift+comma to reload. Cmd+T will open a separate window."
        echo "Move any existing tabs to separate windows using Window > Move Tab to New Window."
    else
        echo "Ghostty not found; no Ghostty settings were changed. Rerun after installing it."
    fi
)

find_aerospace_cli() {
    local candidate
    for candidate in "$(command -v aerospace || true)" /opt/homebrew/bin/aerospace /usr/local/bin/aerospace; do
        if [[ -n "$candidate" && -x "$candidate" ]]; then printf '%s\n' "$candidate"; return; fi
    done
    echo "Install AeroSpace first: brew install --cask nikitabobko/tap/aerospace" >&2
    return 1
}

ghostty_installed() {
    [[ -d /Applications/Ghostty.app || -d "$HOME/Applications/Ghostty.app" ]] || command -v ghostty >/dev/null 2>&1
}

activate_harmony() {
    local cli="$1" user_dir="${2:-$HOME}"
    local helper="$user_dir/.config/aerospace/bin/aerospace-shortcuts"
    local pid command attempt helper_pid
    if pgrep -u "$(id -u)" -x AeroSpace >/dev/null; then
        "$cli" reload-config --no-gui || return 1
        # Match the exact installed helper command, never unrelated processes.
        while read -r pid command; do
            if [[ "$command" == "$helper hotkey" ]]; then
                kill "$pid" 2>/dev/null || true
                for ((attempt=0; attempt<20; attempt++)); do
                    if ! kill -0 "$pid" 2>/dev/null; then break; fi
                    sleep 0.1
                done
            fi
        done < <(ps -ww -u "$(id -u)" -o pid=,command=)
        nohup "$helper" hotkey >> "$user_dir/Library/Logs/AeroSpace-shortcuts.log" 2>&1 < /dev/null &
        helper_pid=$!
        sleep 0.5
        kill -0 "$helper_pid" 2>/dev/null || return 1
        echo "AeroSpace reloaded; the Escape helper is running."
    else
        open -a AeroSpace || return 1
        echo "AeroSpace opened. Allow Accessibility access if macOS asks."
    fi
}

main() {
    if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --dry-run ) ]]; then
        echo "Usage: ./install.sh [--dry-run]" >&2
        return 2
    fi
    if [[ "$(uname -s)" != Darwin ]]; then
        echo "AeroSpace Harmony requires macOS." >&2
        return 1
    fi
    local project_dir cli has_ghostty=no
    project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    cli="$(find_aerospace_cli)"
    if ! xcode-select -p >/dev/null 2>&1 || ! xcrun --find swiftc >/dev/null 2>&1; then
        echo "The Escape helper needs Apple's Command Line Tools. Run xcode-select --install, finish the installer, then rerun this command." >&2
        return 1
    fi
    if ghostty_installed; then has_ghostty=yes; fi
    install_payload "$project_dir" "$HOME" "${XDG_CONFIG_HOME:-$HOME/.config}" "$has_ghostty" "${1:-}"
    if [[ "${1:-}" == --dry-run ]]; then return; fi
    if ! activate_harmony "$cli"; then
        echo "Files installed. Quit and reopen AeroSpace to activate the configuration and Escape helper." >&2
        echo "If needed, allow AeroSpace in System Settings > Privacy & Security > Accessibility." >&2
    fi
    echo "Optional: map Caps Lock to Control-Option-Command with Hyperkey; turn OFF 'Include shift in hyper key'."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
