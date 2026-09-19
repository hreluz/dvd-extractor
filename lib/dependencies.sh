#!/usr/bin/env bash
#
# Dependency checks for extractor.sh.

check_dependencies() {
    if ! command -v HandBrakeCLI >/dev/null 2>&1; then
        echo "Error: HandBrakeCLI is not installed."
        echo "Install with:"
        echo "sudo apt install handbrake-cli"
        return 1
    fi

    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo "Error: ffmpeg is not installed."
        echo "Install with:"
        echo "sudo apt install ffmpeg"
        return 1
    fi
}
