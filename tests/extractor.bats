#!/usr/bin/env bats
#
# Unit tests for the pure parsing/validation functions in extractor.sh.
# extractor.sh is sourced (not executed) so main() never runs.

load '/usr/lib/bats/bats-support/load.bash'
load '/usr/lib/bats/bats-assert/load.bash'

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "$SCRIPT_DIR/extractor.sh"
    SCAN_FIXTURE="$(cat "$SCRIPT_DIR/tests/fixtures/scan_output.txt")"
}

# -------------------------------------
# strip_quotes
# -------------------------------------

@test "strip_quotes removes surrounding double quotes" {
    run strip_quotes '"/path/to/movie.iso"'
    assert_success
    assert_output '/path/to/movie.iso'
}

@test "strip_quotes removes surrounding single quotes" {
    run strip_quotes "'/path/to/movie.iso'"
    assert_success
    assert_output '/path/to/movie.iso'
}

@test "strip_quotes leaves unquoted paths untouched" {
    run strip_quotes '/path/to/movie.iso'
    assert_success
    assert_output '/path/to/movie.iso'
}

# -------------------------------------
# default_name_from_iso
# -------------------------------------

@test "default_name_from_iso strips directory and extension" {
    run default_name_from_iso '/home/user/My Movie.iso'
    assert_success
    assert_output 'My Movie'
}

@test "default_name_from_iso handles names without an extension" {
    run default_name_from_iso '/home/user/MovieName'
    assert_success
    assert_output 'MovieName'
}

# -------------------------------------
# parse_recommended_title
# -------------------------------------

@test "parse_recommended_title finds the main feature title" {
    run parse_recommended_title "$SCAN_FIXTURE"
    assert_success
    assert_output '3'
}

@test "parse_recommended_title is empty when no main feature is reported" {
    local scan
    scan=$(printf '+ title 1:\n  + duration: 00:10:00\n')
    run parse_recommended_title "$scan"
    assert_success
    assert_output ''
}

# -------------------------------------
# parse_titles
# -------------------------------------

@test "parse_titles lists all title numbers in order" {
    run parse_titles "$SCAN_FIXTURE"
    assert_success
    assert_line --index 0 '1'
    assert_line --index 1 '2'
    assert_line --index 2 '3'
}

@test "parse_titles is empty when the scan reports no titles" {
    run parse_titles 'No titles found.'
    assert_success
    assert_output ''
}

# -------------------------------------
# get_title_block / get_duration / get_chapter_count
# -------------------------------------

@test "get_duration reports the correct duration for a given title" {
    local block
    block=$(get_title_block "$SCAN_FIXTURE" 2)
    run get_duration "$block"
    assert_success
    assert_output '00:05:30'
}

@test "get_chapter_count reports the correct chapter count for a given title" {
    local block
    block=$(get_title_block "$SCAN_FIXTURE" 3)
    run get_chapter_count "$block"
    assert_success
    assert_output '5'
}

@test "get_title_block does not bleed into the next title's data" {
    local block
    block=$(get_title_block "$SCAN_FIXTURE" 1)
    run get_chapter_count "$block"
    assert_success
    assert_output '4'
}

@test "get_title_block for the last title runs to end of input" {
    local block
    block=$(get_title_block "$SCAN_FIXTURE" 3)
    run get_duration "$block"
    assert_success
    assert_output '01:32:05'
}

# -------------------------------------
# is_valid_title
# -------------------------------------

@test "is_valid_title accepts a known title" {
    run is_valid_title 2 1 2 3
    assert_success
}

@test "is_valid_title rejects an unknown title" {
    run is_valid_title 9 1 2 3
    assert_failure
}

@test "is_valid_title rejects when there are no titles" {
    run is_valid_title 1
    assert_failure
}
