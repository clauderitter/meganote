# Meganote

A persistent single-document note-taking app for macOS. Always running, always saving.

## What it does

- One document, always open — close the window and it hides, click the dock icon and it's back
- Date-sectioned entries — today's header is created automatically
- Slash commands: `/bookmark`, `/try`, `/help` — type a command, press Enter, get a styled chip
- Snippets dropdown — quick-jump to any bookmark or try entry
- Search (Cmd+F) with match highlighting and navigation
- Auto-save with 2-second debounce
- Plain markdown storage at `~/Documents/Meganote/meganote.md`

## Build

Requires macOS 13+ and Swift 5.9+.

```
./build.sh
```

This produces `Meganote.app` (ad-hoc codesigned). Copy to `/Applications` or run directly.

## Tech

Swift, AppKit, SPM. No external dependencies. ~2500 lines of code, ~10-20MB memory.
