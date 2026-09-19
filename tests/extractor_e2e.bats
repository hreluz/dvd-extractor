#!/usr/bin/env bats
#
# End-to-end smoke tests for extractor.sh, driven via stdin with
# HandBrakeCLI/ffmpeg replaced by stub scripts under tests/mocks/.

load '/usr/lib/bats/bats-support/load.bash'
load '/usr/lib/bats/bats-assert/load.bash'

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    TEST_TMP="$(mktemp -d)"

    ISO="$TEST_TMP/movie.iso"
    : > "$ISO"

    export SCAN_FIXTURE_PATH="$SCRIPT_DIR/tests/fixtures/scan_output.txt"
    export PATH="$SCRIPT_DIR/tests/mocks:$PATH"
}

teardown() {
    rm -rf "$TEST_TMP"
}

@test "extractor.sh extracts the recommended title end-to-end with mocked tools" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF

$ISO



Y
EOF

    assert_success
    assert_output --partial "HandBrake Main Feature"
    assert_output --partial "Finished"

    [ -f "movie_extracted/title_3/videos/chapter_01.mp4" ]
    [ -f "movie_extracted/title_3/videos/chapter_05.mp4" ]
    [ -f "movie_extracted/title_3/audios/chapter_01.mp3" ]
    [ -f "movie_extracted/title_3/audios/chapter_05.mp3" ]
    [ ! -f "movie_extracted/title_3/videos/chapter_06.mp4" ]
}

@test "extractor.sh skips MP3 extraction in video-only mode" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF
2
$ISO



Y
EOF

    assert_success
    assert_output --partial "Finished"
    refute_output --partial "Audios:"

    [ -f "movie_extracted/title_3/videos/chapter_01.mp4" ]
    [ ! -d "movie_extracted/title_3/audios" ]
}

@test "extractor.sh skips the video file entirely in audio-only mode" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF
3
$ISO



Y
EOF

    assert_success
    assert_output --partial "Finished"
    refute_output --partial "Videos:"

    [ -f "movie_extracted/title_3/audios/chapter_01.mp3" ]
    [ -f "movie_extracted/title_3/audios/chapter_05.mp3" ]
    [ ! -d "movie_extracted/title_3/videos" ]
}

@test "extractor.sh honors a custom output name and explicit title selection" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF

$ISO
custom_name

1
Y
EOF

    assert_success
    [ -d "custom_name_extracted/title_1/videos" ]
    [ -f "custom_name_extracted/title_1/videos/chapter_04.mp4" ]
    [ ! -f "custom_name_extracted/title_1/videos/chapter_05.mp4" ]
}

@test "extractor.sh writes into a custom output directory" {
    cd "$TEST_TMP"

    mkdir -p "$TEST_TMP/out_here"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF

$ISO

$TEST_TMP/out_here

Y
EOF

    assert_success
    assert_output --partial "Output:   $TEST_TMP/out_here/movie_extracted/title_3"
    [ -f "$TEST_TMP/out_here/movie_extracted/title_3/videos/chapter_01.mp4" ]
    [ ! -d "$TEST_TMP/movie_extracted" ]
}

@test "extractor.sh creates a nonexistent output directory" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF

$ISO

$TEST_TMP/does/not/exist/yet

Y
EOF

    assert_success
    [ -f "$TEST_TMP/does/not/exist/yet/movie_extracted/title_3/videos/chapter_01.mp4" ]
}

@test "extractor.sh reprompts instead of exiting for a missing ISO" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF

/no/such/file.iso
$ISO



Y
EOF

    assert_success
    assert_output --partial "ISO not found: /no/such/file.iso"
    assert_output --partial "Finished"
    [ -f "movie_extracted/title_3/videos/chapter_01.mp4" ]
}

@test "extractor.sh quits cleanly from the ISO prompt" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF

q
EOF

    assert_success
    assert_output --partial "Exiting."
    [ ! -d "movie_extracted" ]
}

@test "extractor.sh goes back to the extract-mode menu from the ISO prompt" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF

b
2
$ISO



Y
EOF

    assert_success
    assert_output --partial "Finished"
    refute_output --partial "Audios:"
    [ -f "movie_extracted/title_3/videos/chapter_01.mp4" ]
}

@test "extractor.sh reprompts instead of exiting on an invalid extract-mode choice" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF
9
1
$ISO



Y
EOF

    assert_success
    assert_output --partial "Invalid choice: 9"
    assert_output --partial "Finished"
    [ -f "movie_extracted/title_3/videos/chapter_01.mp4" ]
}

@test "extractor.sh quits cleanly from the extract-mode menu" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF
q
EOF

    assert_success
    assert_output --partial "Exiting."
    [ ! -d "movie_extracted" ]
}

@test "extractor.sh reprompts instead of exiting on an invalid title choice" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF

$ISO


99
3
Y
EOF

    assert_success
    assert_output --partial "Invalid title: 99"
    assert_output --partial "Finished"
    [ -f "movie_extracted/title_3/videos/chapter_01.mp4" ]
}

@test "extractor.sh quits cleanly from the title selection menu" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF

$ISO


q
EOF

    assert_success
    assert_output --partial "Exiting."
    [ ! -d "movie_extracted" ]
}

@test "extractor.sh reprompts when the output directory path is an existing file" {
    cd "$TEST_TMP"

    : > "$TEST_TMP/not_a_dir"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF

$ISO

$TEST_TMP/not_a_dir
$TEST_TMP/out_here

Y
EOF

    assert_success
    assert_output --partial "Output path exists and is not a directory: $TEST_TMP/not_a_dir"
    assert_output --partial "Finished"
    [ -f "$TEST_TMP/out_here/movie_extracted/title_3/videos/chapter_01.mp4" ]
}

@test "extractor.sh quits cleanly from the output directory prompt" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF

$ISO

q
EOF

    assert_success
    assert_output --partial "Exiting."
    [ ! -d "movie_extracted" ]
}

@test "extractor.sh goes back to the output name prompt from the output directory prompt" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF

$ISO

b
custom_name


Y
EOF

    assert_success
    assert_output --partial "Finished"
    [ -f "custom_name_extracted/title_3/videos/chapter_01.mp4" ]
}

@test "extractor.sh cancels cleanly when extraction is declined" {
    cd "$TEST_TMP"

    run bash "$SCRIPT_DIR/extractor.sh" <<EOF

$ISO



n
EOF

    assert_success
    assert_output --partial "Cancelled"
    [ ! -d "movie_extracted" ]
}
