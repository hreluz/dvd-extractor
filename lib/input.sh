#!/usr/bin/env bash
#
# User input handling: quote stripping and output name/path defaults.

strip_quotes() {
    local value="$1"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    printf '%s' "$value"
}

default_name_from_iso() {
    local iso="$1"
    local name
    name=$(basename "$iso")
    printf '%s' "${name%.*}"
}

resolve_output_path() {
    local output_dir="$1"
    local name="$2"
    local title="$3"
    output_dir="${output_dir%/}"
    printf '%s/%s_extracted/title_%s' "$output_dir" "$name" "$title"
}

resolve_extract_mode() {
    local choice="$1"
    case "$choice" in
        ""|1) printf 'both' ;;
        2) printf 'video' ;;
        3) printf 'audio' ;;
        *) return 1 ;;
    esac
}

resolve_source_type() {
    local choice="$1"
    case "$choice" in
        ""|1) printf 'iso' ;;
        2) printf 'disc' ;;
        *) return 1 ;;
    esac
}

list_dvd_drives() {
    local pattern="${DVD_DRIVE_GLOB:-/dev/sr*}"
    local drive
    for drive in $pattern; do
        if [ -e "$drive" ]; then
            printf '%s\n' "$drive"
        fi
    done
}
