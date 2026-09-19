# CLAUDE.md

This file gives Claude Code guidance for working in this repository.

## Project overview

DVD Chapter Extractor: a single interactive bash script (`extractor.sh`) that rips a DVD ISO into
per-chapter MP4 videos and MP3 audio files, using `HandBrakeCLI` for video extraction and `ffmpeg`
for audio extraction. There is no build system or package manager — the project is the one script
plus its `tests/` suite.

## Running / testing changes

Automated tests use bats-core and don't need a real DVD ISO — HandBrakeCLI/ffmpeg are stubbed:

```bash
bats tests/
```

Run this after any change to `extractor.sh`. See `tests/extractor.bats` (unit tests for the
parsing/validation functions) and `tests/extractor_e2e.bats` (full-script smoke tests driven via
stdin with mocked `HandBrakeCLI`/`ffmpeg` from `tests/mocks/`). If bats isn't installed, ask the
user to run `sudo apt install bats bats-support bats-assert` themselves (needs a password).

For a final sanity check beyond the test suite, run the script against a real DVD ISO:

```bash
./extractor.sh
```

## Script structure

`extractor.sh` defines a set of small functions, then a `main()` that runs the interactive flow
end to end (with `set -e`). `main()` only executes when the script is run directly — sourcing the
file (as the unit tests do) loads the functions without running `main`.

Functions:

- `check_dependencies` — verifies `HandBrakeCLI` and `ffmpeg` are on PATH
- `strip_quotes` — strips a single layer of surrounding `'` or `"` from user input
- `default_name_from_iso` — derives the default output name from the ISO path (basename, no extension)
- `parse_recommended_title` — extracts HandBrake's "Found main feature title N" from scan output
- `parse_titles` — extracts all `+ title N:` numbers from scan output
- `get_title_block` — slices the scan output down to one title's block
- `get_duration` / `get_chapter_count` — pull duration and chapter count out of a title block
- `is_valid_title` — checks a candidate title number against the known title list

`main()` flow, in order:

1. Dependency checks
2. Prompt for ISO path, validate it exists
3. Prompt for output name (defaults to ISO basename)
4. `HandBrakeCLI --scan --main-feature` to enumerate titles and detect the recommended one
5. Parse scan output to list titles, durations, and chapter counts
6. Prompt for title selection, validate it
7. Confirm before extracting
8. Create `NAME_extracted/title_TITLE/{videos,audios}` directories
9. Loop over chapters: `HandBrakeCLI` extracts each chapter to MP4 (`Fast 480p30` preset), then
   `ffmpeg` extracts the corresponding MP3 (`libmp3lame`, 192k) from that video

## Conventions to follow when editing

- Keep the section-divider comment style (`# ----` blocks with a short label) used throughout.
- Keep output formatted with the `====` banner style already used for section headers.
- Parsing of HandBrake's scan output relies on specific `sed`/`grep` patterns matching HandBrake's
  text format — if you change how titles/chapters are parsed, verify against real `--scan` output,
  since HandBrake's output format is not guaranteed stable across versions.
- Preserve `set -e` behavior; don't silently swallow errors from `HandBrakeCLI`/`ffmpeg`.
- This is a personal utility script — keep it simple and dependency-free (plain bash + the two
  external CLIs). Avoid introducing additional tooling unless the user asks for it.
