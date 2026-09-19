#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/dependencies.sh"
source "$SCRIPT_DIR/lib/input.sh"
source "$SCRIPT_DIR/lib/scan.sh"

main() {
    echo "======================================"
    echo "       DVD Chapter Extractor"
    echo "======================================"
    echo

    check_dependencies || exit 1

    # -------------------------------------
    # Ask for ISO
    # -------------------------------------

    read -rp "Enter the path to the DVD ISO: " ISO
    ISO=$(strip_quotes "$ISO")

    if [ ! -f "$ISO" ]; then
        echo
        echo "Error: ISO not found:"
        echo "$ISO"
        exit 1
    fi

    # -------------------------------------
    # Ask for output name
    # -------------------------------------

    DEFAULT_NAME=$(default_name_from_iso "$ISO")

    read -rp "Output name [$DEFAULT_NAME]: " NAME
    NAME="${NAME:-$DEFAULT_NAME}"

    # -------------------------------------
    # Ask for output directory
    # -------------------------------------

    read -rp "Output directory [.]: " OUTPUT_DIR
    OUTPUT_DIR="${OUTPUT_DIR:-.}"
    OUTPUT_DIR=$(strip_quotes "$OUTPUT_DIR")

    # -------------------------------------
    # Scan DVD
    # -------------------------------------

    echo
    echo "Scanning DVD..."
    echo "This may take a moment."
    echo

    SCAN=$(HandBrakeCLI \
        -i "$ISO" \
        --scan \
        --main-feature \
        2>&1)

    # -------------------------------------
    # Find HandBrake recommended title
    # -------------------------------------

    RECOMMENDED_TITLE=$(parse_recommended_title "$SCAN")

    # -------------------------------------
    # Parse titles
    # -------------------------------------

    mapfile -t TITLES < <(parse_titles "$SCAN")

    if [ "${#TITLES[@]}" -eq 0 ]; then
        echo "Error: No DVD titles were detected."
        exit 1
    fi

    # -------------------------------------
    # Display titles
    # -------------------------------------

    echo "======================================"
    echo "DVD titles found"
    echo "======================================"
    echo

    for TITLE_NUMBER in "${TITLES[@]}"; do

        TITLE_BLOCK=$(get_title_block "$SCAN" "$TITLE_NUMBER")
        DURATION=$(get_duration "$TITLE_BLOCK")
        CHAPTER_COUNT=$(get_chapter_count "$TITLE_BLOCK")

        if [ "$TITLE_NUMBER" = "$RECOMMENDED_TITLE" ]; then
            printf "  %s) Title %-3s  Duration: %-10s  Chapters: %-3s  <-- HandBrake Main Feature\n" \
                "$TITLE_NUMBER" \
                "$TITLE_NUMBER" \
                "$DURATION" \
                "$CHAPTER_COUNT"
        else
            printf "  %s) Title %-3s  Duration: %-10s  Chapters: %-3s\n" \
                "$TITLE_NUMBER" \
                "$TITLE_NUMBER" \
                "$DURATION" \
                "$CHAPTER_COUNT"
        fi

    done

    echo

    # -------------------------------------
    # Ask user which title to extract
    # -------------------------------------

    if [ -n "$RECOMMENDED_TITLE" ]; then
        read -rp "Select title [$RECOMMENDED_TITLE]: " TITLE
        TITLE="${TITLE:-$RECOMMENDED_TITLE}"
    else
        read -rp "Select title: " TITLE
    fi

    # -------------------------------------
    # Validate selected title
    # -------------------------------------

    if ! is_valid_title "$TITLE" "${TITLES[@]}"; then
        echo
        echo "Error: Invalid title: $TITLE"
        exit 1
    fi

    # -------------------------------------
    # Get selected title information
    # -------------------------------------

    TITLE_BLOCK=$(get_title_block "$SCAN" "$TITLE")
    DURATION=$(get_duration "$TITLE_BLOCK")
    CHAPTERS=$(get_chapter_count "$TITLE_BLOCK")

    if [ "$CHAPTERS" -eq 0 ]; then
        echo
        echo "Error: Could not determine chapter count."
        exit 1
    fi

    OUTPUT=$(resolve_output_path "$OUTPUT_DIR" "$NAME" "$TITLE")

    # -------------------------------------
    # Show selection
    # -------------------------------------

    echo
    echo "======================================"
    echo "Selected DVD title"
    echo "======================================"
    echo
    echo "ISO:      $ISO"
    echo "Title:    $TITLE"
    echo "Duration: $DURATION"
    echo "Chapters: $CHAPTERS"
    echo "Output:   $OUTPUT"
    echo

    read -rp "Extract this title? [Y/n]: " CONFIRM
    CONFIRM="${CONFIRM:-Y}"

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    # -------------------------------------
    # Create output directories
    # -------------------------------------

    VIDEO_DIR="$OUTPUT/videos"
    AUDIO_DIR="$OUTPUT/audios"

    mkdir -p "$VIDEO_DIR"
    mkdir -p "$AUDIO_DIR"

    echo
    echo "Output directory:"
    echo "$OUTPUT"

    # -------------------------------------
    # Extract chapters
    # -------------------------------------

    for ((i=1; i<=CHAPTERS; i++)); do

        NUMBER=$(printf "%02d" "$i")

        VIDEO="$VIDEO_DIR/chapter_${NUMBER}.mp4"
        AUDIO="$AUDIO_DIR/chapter_${NUMBER}.mp3"

        echo
        echo "======================================"
        echo "Chapter $i / $CHAPTERS"
        echo "======================================"
        echo

        echo "Creating video..."
        echo

        HandBrakeCLI \
            -i "$ISO" \
            -o "$VIDEO" \
            --title "$TITLE" \
            --chapters "$i-$i" \
            --preset "Fast 480p30"

        echo
        echo "Creating MP3..."
        echo

        ffmpeg \
            -hide_banner \
            -loglevel warning \
            -y \
            -i "$VIDEO" \
            -vn \
            -c:a libmp3lame \
            -b:a 192k \
            "$AUDIO"

        echo
        echo "Chapter $i completed."

    done

    # -------------------------------------
    # Finished
    # -------------------------------------

    echo
    echo "======================================"
    echo "              Finished"
    echo "======================================"
    echo
    echo "Title: $TITLE"
    echo "Videos:"
    echo "  $VIDEO_DIR"
    echo
    echo "Audios:"
    echo "  $AUDIO_DIR"
    echo
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
