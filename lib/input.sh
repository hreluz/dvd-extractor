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
