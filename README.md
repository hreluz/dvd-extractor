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

1. **What to extract** — video (MP4) and audio (MP3), video only, or audio only; defaults to both.
   This is asked first, before anything else.
2. **ISO path** — enter the path to the DVD ISO file.
3. **Output name** — defaults to the ISO filename (without extension).
4. **Output directory** — where the extracted files go; defaults to the current directory (`.`).
5. **Scan** — HandBrake scans the ISO and lists all titles, their duration, and chapter count, highlighting its recommended "main feature" title.
6. **Title selection** — pick a title (defaults to HandBrake's recommendation).
7. **Confirmation** — review the selected title's details before extraction begins.

## Output

For output directory `DIR`, output name `NAME`, and selected title `TITLE`, the script creates:

```
DIR/NAME_extracted/title_TITLE/
├── videos/             (skipped in audio-only mode)
│   ├── chapter_01.mp4
│   ├── chapter_02.mp4
│   └── ...
└── audios/              (skipped in video-only mode)
    ├── chapter_01.mp3
    ├── chapter_02.mp3
    └── ...
```

`DIR` (and any missing parent directories) is created automatically if it doesn't already exist.

Each chapter of the selected title is extracted individually:

- **Video**: MP4 via HandBrakeCLI, `Fast 480p30` preset.
- **Audio**: MP3 extracted with ffmpeg (`libmp3lame`, 192k). In **audio-only** mode, HandBrakeCLI's
  output is piped directly into ffmpeg instead of being written to a `.mp4` first — the video is
  still encoded internally (HandBrakeCLI has no audio-only mode), but the file itself is never
  written to disk, so extraction is lighter on disk space and I/O even though it takes the same
  amount of time as extracting video.

## Project layout

- `extractor.sh` — entry point; sources `lib/` and runs the interactive flow.
- `lib/dependencies.sh` — checks `HandBrakeCLI`/`ffmpeg` are installed.
- `lib/input.sh` — quote stripping and output name/path defaults.
- `lib/scan.sh` — parsing and validation of HandBrakeCLI `--scan` output.

## Testing

Tests use [bats-core](https://github.com/bats-core/bats-core):

```bash
sudo apt install bats bats-support bats-assert
bats -r tests/
```

(`-r` is required to pick up the nested `tests/lib/` unit tests.)

- `tests/lib/dependencies.bats`, `tests/lib/input.bats`, `tests/lib/scan.bats` — unit tests for
  each `lib/` module, run by sourcing that module directly.
- `tests/extractor_e2e.bats` — end-to-end smoke tests that run the full interactive script with
  `HandBrakeCLI`/`ffmpeg` replaced by stub scripts under `tests/mocks/`, so no real DVD ISO is
  needed.
