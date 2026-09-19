#!/usr/bin/env bats
#
# Unit tests for lib/input.sh.

load '/usr/lib/bats/bats-support/load.bash'
load '/usr/lib/bats/bats-assert/load.bash'

setup() {
    ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$ROOT_DIR/lib/input.sh"
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
# resolve_output_path
# -------------------------------------

@test "resolve_output_path builds the path under the current directory" {
    run resolve_output_path '.' 'movie' '3'
    assert_success
    assert_output './movie_extracted/title_3'
}

@test "resolve_output_path builds the path under a custom directory" {
    run resolve_output_path '/mnt/media' 'movie' '3'
    assert_success
    assert_output '/mnt/media/movie_extracted/title_3'
}

@test "resolve_output_path strips a trailing slash from the directory" {
    run resolve_output_path '/mnt/media/' 'movie' '3'
    assert_success
    assert_output '/mnt/media/movie_extracted/title_3'
}

@test "resolve_output_path handles the root directory" {
    run resolve_output_path '/' 'movie' '3'
    assert_success
    assert_output '/movie_extracted/title_3'
}

@test "resolve_output_path handles a relative subdirectory" {
    run resolve_output_path 'some/dir' 'movie' '3'
    assert_success
    assert_output 'some/dir/movie_extracted/title_3'
}

# -------------------------------------
# resolve_extract_mode
# -------------------------------------

@test "resolve_extract_mode defaults to both on a blank choice" {
    run resolve_extract_mode ''
    assert_success
    assert_output 'both'
}

@test "resolve_extract_mode maps 1 to both" {
    run resolve_extract_mode '1'
    assert_success
    assert_output 'both'
}

@test "resolve_extract_mode maps 2 to video" {
    run resolve_extract_mode '2'
    assert_success
    assert_output 'video'
}

@test "resolve_extract_mode maps 3 to audio" {
    run resolve_extract_mode '3'
    assert_success
    assert_output 'audio'
}

@test "resolve_extract_mode rejects an unknown choice" {
    run resolve_extract_mode '9'
    assert_failure
}
