# CLAUDE.md

This file gives Claude Code guidance for working in this repository.

## Project overview

DVD Chapter Extractor: an interactive bash tool (`extractor.sh` + `lib/`) that rips a DVD ISO into
per-chapter MP4 videos and MP3 audio files, using `HandBrakeCLI` for video extraction and `ffmpeg`
for audio extraction. There is no build system or package manager — the project is the script, its
`lib/` modules, and the `tests/` suite.

## Running / testing changes

Automated tests use bats-core and don't need a real DVD ISO — HandBrakeCLI/ffmpeg are stubbed:

```bash
bats -r tests/
```

`-r` is required — it recurses into `tests/lib/`, which plain `bats tests/` skips. Run this after
any change to `extractor.sh` or `lib/`. See `tests/lib/*.bats` (unit tests for each `lib/` module)
and `tests/extractor_e2e.bats` (full-script smoke tests driven via stdin with mocked
`HandBrakeCLI`/`ffmpeg` from `tests/mocks/`). If bats isn't installed, ask the user to run
`sudo apt install bats bats-support bats-assert` themselves (needs a password).

For a final sanity check beyond the test suite, run the script against a real DVD ISO:

```bash
./extractor.sh
```

## Script structure

`extractor.sh` is the entry point: it sources the `lib/` modules, defines `main()` (the
interactive flow, run with `set -e`), and only calls `main()` when executed directly — sourcing
the file (as `lib/`-adjacent tooling might) loads nothing extra since the functions themselves
live in `lib/`.

`lib/dependencies.sh`:

- `check_dependencies` — verifies `HandBrakeCLI` and `ffmpeg` are on PATH

`lib/input.sh`:

- `strip_quotes` — strips a single layer of surrounding `'` or `"` from user input
- `default_name_from_iso` — derives the default output name from the ISO path (basename, no extension)
- `resolve_output_path` — joins output directory, output name, and title into the final
  `DIR/NAME_extracted/title_TITLE` path (strips a trailing slash from `DIR`)

`lib/scan.sh`:

- `parse_recommended_title` — extracts HandBrake's "Found main feature title N" from scan output
- `parse_titles` — extracts all `+ title N:` numbers from scan output
- `get_title_block` — slices the scan output down to one title's block
- `get_duration` / `get_chapter_count` — pull duration and chapter count out of a title block
- `is_valid_title` — checks a candidate title number against the known title list

Each `tests/lib/*.bats` file sources its matching `lib/*.sh` module directly (not `extractor.sh`),
so unit tests stay isolated to one module. When adding a function, put it in the module matching
its responsibility (dependency checks / input & path handling / scan parsing) and add its test to
the corresponding `tests/lib/*.bats` file — don't grow `extractor.sh` itself beyond `main()`.

`main()` flow, in order:

1. Dependency checks
2. Prompt for ISO path, validate it exists
3. Prompt for output name (defaults to ISO basename)
4. Prompt for output directory (defaults to `.`)
5. `HandBrakeCLI --scan --main-feature` to enumerate titles and detect the recommended one
6. Parse scan output to list titles, durations, and chapter counts
7. Prompt for title selection, validate it
8. Prompt whether to also extract MP3 audio (`EXTRACT_AUDIO`, defaults to yes)
9. Confirm before extracting
10. Create `OUTPUT_DIR/NAME_extracted/title_TITLE/videos` (and `.../audios` too, if audio was
    requested) directories (`resolve_output_path` builds the base path; `mkdir -p` creates any
    missing parent directories)
11. Loop over chapters: `HandBrakeCLI` extracts each chapter to MP4 (`Fast 480p30` preset), then,
    if audio was requested, `ffmpeg` extracts the corresponding MP3 (`libmp3lame`, 192k) from that
    video

## Conventions to follow when editing

- Keep the section-divider comment style (`# ----` blocks with a short label) used throughout.
- Keep output formatted with the `====` banner style already used for section headers.
- Parsing of HandBrake's scan output relies on specific `sed`/`grep` patterns matching HandBrake's
  text format — if you change how titles/chapters are parsed, verify against real `--scan` output,
  since HandBrake's output format is not guaranteed stable across versions.
- Preserve `set -e` behavior; don't silently swallow errors from `HandBrakeCLI`/`ffmpeg`.
- This is a personal utility script — keep it simple and dependency-free (plain bash + the two
  external CLIs). Avoid introducing additional tooling unless the user asks for it.
