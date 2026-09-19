#!/usr/bin/env bash
#
# Parsing and validation of HandBrakeCLI --scan output.

parse_recommended_title() {
    local scan="$1"
    echo "$scan" |
        sed -n 's/.*Found main feature title \([0-9]\+\).*/\1/p' |
        head -1
}

parse_titles() {
    local scan="$1"
    echo "$scan" |
        sed -n 's/^+ title \([0-9]\+\):/\1/p'
}

get_title_block() {
    local scan="$1"
    local title="$2"
    echo "$scan" |
        sed -n "/^+ title ${title}:/,/^+ title /p"
}

get_duration() {
    local title_block="$1"
    echo "$title_block" |
        grep "duration:" |
        head -1 |
        sed 's/.*duration: //'
}

get_chapter_count() {
    local title_block="$1"
    echo "$title_block" |
        sed -n '/+ chapters:/,/+ audio tracks:/p' |
        grep -E '^[[:space:]]+\+ [0-9]+:' |
        wc -l
}

is_valid_title() {
    local candidate="$1"
    shift
    local t
    for t in "$@"; do
        if [ "$t" = "$candidate" ]; then
            return 0
        fi
    done
    return 1
}
