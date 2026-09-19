#!/usr/bin/env bash

set -e
set -o pipefail

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
    # Ask what to extract
    # -------------------------------------

    while true; do

        while true; do
            echo "What do you want to extract for each chapter?"
            echo "  1) Video (MP4) and audio (MP3)"
            echo "  2) Video (MP4) only"
            echo "  3) Audio (MP3) only — no video file is kept"
            echo "  q) Quit"

            if ! read -rp "Choose [1]: " EXTRACT_CHOICE; then
                echo
                exit 1
            fi

            if [[ "$EXTRACT_CHOICE" =~ ^[Qq]$ ]]; then
                echo "Exiting."
                exit 0
            fi

            if EXTRACT_MODE=$(resolve_extract_mode "$EXTRACT_CHOICE"); then
                break
            fi

            echo
            echo "Invalid choice: $EXTRACT_CHOICE"
            echo
        done

        echo

        # -------------------------------------
        # Ask for the source: ISO file or DVD disc
        # -------------------------------------

        while true; do

            while true; do
                echo "Where do you want to read the DVD from?"
                echo "  1) ISO file"
                echo "  2) DVD disc (optical drive)"
                echo "  b) Back"
                echo "  q) Quit"

                if ! read -rp "Choose [1]: " SOURCE_CHOICE; then
                    echo
                    exit 1
                fi

                if [[ "$SOURCE_CHOICE" =~ ^[Qq]$ ]]; then
                    echo "Exiting."
                    exit 0
                fi

                if [[ "$SOURCE_CHOICE" =~ ^[Bb]$ ]]; then
                    echo
                    continue 3
                fi

                if SOURCE_TYPE=$(resolve_source_type "$SOURCE_CHOICE"); then
                    break
                fi

                echo
                echo "Invalid choice: $SOURCE_CHOICE"
                echo
            done

            echo

            if [ "$SOURCE_TYPE" = "iso" ]; then

                # -------------------------------------
                # Ask for ISO path
                # -------------------------------------

                while true; do
                    if ! read -rp "Enter the path to the DVD ISO (b to go back, q to quit): " ISO; then
                        echo
                        exit 1
                    fi
                    ISO=$(strip_quotes "$ISO")

                    if [[ "$ISO" =~ ^[Qq]$ ]]; then
                        echo "Exiting."
                        exit 0
                    fi

                    if [[ "$ISO" =~ ^[Bb]$ ]]; then
                        echo
                        continue 2
                    fi

                    if [ -f "$ISO" ]; then
                        break
                    fi

                    echo
                    echo "ISO not found: $ISO"
                    echo
                done

            else

                # -------------------------------------
                # Detect and select a DVD drive
                # -------------------------------------

                mapfile -t DRIVES < <(list_dvd_drives)

                if [ "${#DRIVES[@]}" -eq 0 ]; then
                    echo "No DVD drives detected."
                    echo
                    continue
                fi

                if [ "${#DRIVES[@]}" -eq 1 ]; then
                    ISO="${DRIVES[0]}"
                    echo "Using DVD drive: $ISO"
                else
                    echo "Multiple DVD drives found:"
                    for i in "${!DRIVES[@]}"; do
                        printf "  %d) %s\n" "$((i + 1))" "${DRIVES[$i]}"
                    done
                    echo

                    while true; do
                        if ! read -rp "Select drive [1] (b to go back, q to quit): " DRIVE_CHOICE; then
                            echo
                            exit 1
                        fi

                        if [[ "$DRIVE_CHOICE" =~ ^[Qq]$ ]]; then
                            echo "Exiting."
                            exit 0
                        fi

                        if [[ "$DRIVE_CHOICE" =~ ^[Bb]$ ]]; then
                            echo
                            continue 2
                        fi

                        DRIVE_CHOICE="${DRIVE_CHOICE:-1}"

                        if [[ "$DRIVE_CHOICE" =~ ^[0-9]+$ ]] && [ "$DRIVE_CHOICE" -ge 1 ] && [ "$DRIVE_CHOICE" -le "${#DRIVES[@]}" ]; then
                            ISO="${DRIVES[$((DRIVE_CHOICE - 1))]}"
                            break
                        fi

                        echo
                        echo "Invalid choice: $DRIVE_CHOICE"
                        echo
                    done
                fi
            fi

            break
        done

        break
    done

    DEFAULT_NAME=$(default_name_from_iso "$ISO")

    while true; do

        # -------------------------------------
        # Ask for output name
        # -------------------------------------

        if ! read -rp "Output name [$DEFAULT_NAME]: " NAME; then
            echo
            exit 1
        fi
        NAME="${NAME:-$DEFAULT_NAME}"

        # -------------------------------------
        # Ask for output directory
        # -------------------------------------

        while true; do
            if ! read -rp "Output directory [.] (b to go back, q to quit): " OUTPUT_DIR; then
                echo
                exit 1
            fi

            if [[ "$OUTPUT_DIR" =~ ^[Qq]$ ]]; then
                echo "Exiting."
                exit 0
            fi

            if [[ "$OUTPUT_DIR" =~ ^[Bb]$ ]]; then
                echo
                continue 2
            fi

            OUTPUT_DIR="${OUTPUT_DIR:-.}"
            OUTPUT_DIR=$(strip_quotes "$OUTPUT_DIR")

            if [ -e "$OUTPUT_DIR" ] && [ ! -d "$OUTPUT_DIR" ]; then
                echo
                echo "Output path exists and is not a directory: $OUTPUT_DIR"
                echo
                continue
            fi

            break
        done

        break
    done

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

    while true; do
        if [ -n "$RECOMMENDED_TITLE" ]; then
            if ! read -rp "Select title [$RECOMMENDED_TITLE] (q to quit): " TITLE; then
                echo
                exit 1
            fi
            TITLE="${TITLE:-$RECOMMENDED_TITLE}"
        else
            if ! read -rp "Select title (q to quit): " TITLE; then
                echo
                exit 1
            fi
        fi

        if [[ "$TITLE" =~ ^[Qq]$ ]]; then
            echo "Exiting."
            exit 0
        fi

        if is_valid_title "$TITLE" "${TITLES[@]}"; then
            break
        fi

        echo
        echo "Invalid title: $TITLE"
        echo
    done

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

    if [[ "$EXTRACT_MODE" == "both" || "$EXTRACT_MODE" == "video" ]]; then
        mkdir -p "$VIDEO_DIR"
    fi
    if [[ "$EXTRACT_MODE" == "both" || "$EXTRACT_MODE" == "audio" ]]; then
        mkdir -p "$AUDIO_DIR"
    fi

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

        case "$EXTRACT_MODE" in
            both)
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
                ;;

            video)
                echo "Creating video..."
                echo

                HandBrakeCLI \
                    -i "$ISO" \
                    -o "$VIDEO" \
                    --title "$TITLE" \
                    --chapters "$i-$i" \
                    --preset "Fast 480p30"
                ;;

            audio)
                echo "Creating MP3..."
                echo

                HandBrakeCLI \
                    -i "$ISO" \
                    -o - \
                    --title "$TITLE" \
                    --chapters "$i-$i" \
                    --preset "Fast 480p30" \
                    --format av_mp4 |
                ffmpeg \
                    -hide_banner \
                    -loglevel warning \
                    -y \
                    -i pipe:0 \
                    -vn \
                    -c:a libmp3lame \
                    -b:a 192k \
                    "$AUDIO"
                ;;
        esac

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

    if [[ "$EXTRACT_MODE" == "both" || "$EXTRACT_MODE" == "video" ]]; then
        echo "Videos:"
        echo "  $VIDEO_DIR"
        echo
    fi

    if [[ "$EXTRACT_MODE" == "both" || "$EXTRACT_MODE" == "audio" ]]; then
        echo "Audios:"
        echo "  $AUDIO_DIR"
        echo
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
