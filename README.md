# DVD Chapter Extractor

An interactive bash script that rips a DVD ISO into per-chapter MP4 videos and MP3 audio files.

## Requirements

- `HandBrakeCLI` (`sudo apt install handbrake-cli`)
- `ffmpeg` (`sudo apt install ffmpeg`)

## Usage

```bash
./extractor.sh
```

The script will walk you through:

1. **ISO path** — enter the path to the DVD ISO file.
2. **Output name** — defaults to the ISO filename (without extension).
3. **Scan** — HandBrake scans the ISO and lists all titles, their duration, and chapter count, highlighting its recommended "main feature" title.
4. **Title selection** — pick a title (defaults to HandBrake's recommendation).
5. **Confirmation** — review the selected title's details before extraction begins.

## Output

For an output name `NAME` and selected title `TITLE`, the script creates:

```
NAME_extracted/title_TITLE/
├── videos/
│   ├── chapter_01.mp4
│   ├── chapter_02.mp4
│   └── ...
└── audios/
    ├── chapter_01.mp3
    ├── chapter_02.mp3
    └── ...
```

Each chapter of the selected title is extracted individually:

- **Video**: MP4 via HandBrakeCLI, `Fast 480p30` preset.
- **Audio**: MP3 extracted from each video with ffmpeg (`libmp3lame`, 192k).

## Testing

Tests use [bats-core](https://github.com/bats-core/bats-core):

```bash
sudo apt install bats bats-support bats-assert
bats tests/
```

- `tests/extractor.bats` — unit tests for the parsing/validation functions (title/duration/chapter
  parsing, quote stripping, title validation), run by sourcing `extractor.sh`.
- `tests/extractor_e2e.bats` — end-to-end smoke tests that run the full interactive script with
  `HandBrakeCLI`/`ffmpeg` replaced by stub scripts under `tests/mocks/`, so no real DVD ISO is
  needed.
