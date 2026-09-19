#!/usr/bin/env bash

set -e

echo "======================================"
echo "       DVD Chapter Extractor"
echo "======================================"
echo

# -------------------------------------
# Check dependencies
# -------------------------------------

if ! command -v HandBrakeCLI >/dev/null 2>&1; then
    echo "Error: HandBrakeCLI is not installed."
    echo "Install with:"
    echo "sudo apt install handbrake-cli"
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Error: ffmpeg is not installed."
    echo "Install with:"
    echo "sudo apt install ffmpeg"
    exit 1
fi

# -------------------------------------
# Ask for ISO
# -------------------------------------

read -rp "Enter the path to the DVD ISO: " ISO

# Remove surrounding quotes
ISO="${ISO%\"}"
ISO="${ISO#\"}"
ISO="${ISO%\'}"
ISO="${ISO#\'}"

if [ ! -f "$ISO" ]; then
    echo
    echo "Error: ISO not found:"
    echo "$ISO"
    exit 1
fi

# -------------------------------------
# Ask for output name
# -------------------------------------

DEFAULT_NAME=$(basename "$ISO")
DEFAULT_NAME="${DEFAULT_NAME%.*}"

read -rp "Output name [$DEFAULT_NAME]: " NAME
NAME="${NAME:-$DEFAULT_NAME}"

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

RECOMMENDED_TITLE=$(echo "$SCAN" |
    sed -n 's/.*Found main feature title \([0-9]\+\).*/\1/p' |
    head -1)

# -------------------------------------
# Parse titles
# -------------------------------------

mapfile -t TITLES < <(
    echo "$SCAN" |
    sed -n 's/^+ title \([0-9]\+\):/\1/p'
)

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

    TITLE_BLOCK=$(echo "$SCAN" |
        sed -n "/^+ title ${TITLE_NUMBER}:/,/^+ title /p")

    DURATION=$(echo "$TITLE_BLOCK" |
        grep "duration:" |
        head -1 |
        sed 's/.*duration: //')

    CHAPTER_COUNT=$(echo "$TITLE_BLOCK" |
        sed -n '/+ chapters:/,/+ audio tracks:/p' |
        grep -E '^[[:space:]]+\+ [0-9]+:' |
        wc -l)

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

VALID_TITLE=false

for T in "${TITLES[@]}"; do
    if [ "$T" = "$TITLE" ]; then
        VALID_TITLE=true
        break
    fi
done

if [ "$VALID_TITLE" != true ]; then
    echo
    echo "Error: Invalid title: $TITLE"
    exit 1
fi

# -------------------------------------
# Get selected title information
# -------------------------------------

TITLE_BLOCK=$(echo "$SCAN" |
    sed -n "/^+ title ${TITLE}:/,/^+ title /p")

DURATION=$(echo "$TITLE_BLOCK" |
    grep "duration:" |
    head -1 |
    sed 's/.*duration: //')

CHAPTERS=$(echo "$TITLE_BLOCK" |
    sed -n '/+ chapters:/,/+ audio tracks:/p' |
    grep -E '^[[:space:]]+\+ [0-9]+:' |
    wc -l)

if [ "$CHAPTERS" -eq 0 ]; then
    echo
    echo "Error: Could not determine chapter count."
    exit 1
fi

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

OUTPUT="${NAME}_extracted/title_${TITLE}"
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
