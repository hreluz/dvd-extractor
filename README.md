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
3. **Output directory** — where the extracted files go; defaults to the current directory (`.`).
4. **Scan** — HandBrake scans the ISO and lists all titles, their duration, and chapter count, highlighting its recommended "main feature" title.
5. **Title selection** — pick a title (defaults to HandBrake's recommendation).
6. **Confirmation** — review the selected title's details before extraction begins.

## Output

For output directory `DIR`, output name `NAME`, and selected title `TITLE`, the script creates:

```
DIR/NAME_extracted/title_TITLE/
├── videos/
│   ├── chapter_01.mp4
│   ├── chapter_02.mp4
│   └── ...
└── audios/
    ├── chapter_01.mp3
    ├── chapter_02.mp3
    └── ...
```

`DIR` (and any missing parent directories) is created automatically if it doesn't already exist.

Each chapter of the selected title is extracted individually:

- **Video**: MP4 via HandBrakeCLI, `Fast 480p30` preset.
- **Audio**: MP3 extracted from each video with ffmpeg (`libmp3lame`, 192k).

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
