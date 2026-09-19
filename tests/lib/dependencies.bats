#!/usr/bin/env bats
#
# Unit tests for lib/dependencies.sh.

load '/usr/lib/bats/bats-support/load.bash'
load '/usr/lib/bats/bats-assert/load.bash'

setup() {
    ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$ROOT_DIR/lib/dependencies.sh"

    FAKE_BIN="$(mktemp -d)"
    REAL_PATH="$PATH"
}

teardown() {
    PATH="$REAL_PATH"
    rm -rf "$FAKE_BIN"
}

@test "check_dependencies succeeds when both tools are on PATH" {
    touch "$FAKE_BIN/HandBrakeCLI" "$FAKE_BIN/ffmpeg"
    chmod +x "$FAKE_BIN/HandBrakeCLI" "$FAKE_BIN/ffmpeg"
    PATH="$FAKE_BIN"

    run check_dependencies
    assert_success
}

@test "check_dependencies fails and explains how to install HandBrakeCLI" {
    touch "$FAKE_BIN/ffmpeg"
    chmod +x "$FAKE_BIN/ffmpeg"
    PATH="$FAKE_BIN"

    run check_dependencies
    assert_failure
    assert_output --partial "HandBrakeCLI is not installed"
    assert_output --partial "sudo apt install handbrake-cli"
}

@test "check_dependencies fails and explains how to install ffmpeg" {
    touch "$FAKE_BIN/HandBrakeCLI"
    chmod +x "$FAKE_BIN/HandBrakeCLI"
    PATH="$FAKE_BIN"

    run check_dependencies
    assert_failure
    assert_output --partial "ffmpeg is not installed"
    assert_output --partial "sudo apt install ffmpeg"
}
