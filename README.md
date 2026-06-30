# Chronos

**Lightweight terminal-based Git repository analytics dashboard.**

Chronos is a single-file Ruby TUI that gives you a live, interactive overview of your Git repository's commit activity — no external dependencies, no bundler, no fuss.

![Chronos screenshot](https://img.shields.io/badge/status-beta-yellow)

## Features

- **Hotspots tab** — Top 5 most frequently changed files, ranked by commit count with visual bar charts
- **Info tab** — Repository overview: directory path, total commits, and branch list
- **Keyboard navigation** — `←` / `→` to switch tabs, `q` to quit
- **No dependencies** — Uses only Ruby stdlib (`io/console`, `English`)
- **Works anywhere** — Run from any directory inside a Git repository

## Installation

1. **Install Ruby** (MRI Ruby 2.x+ — [ruby-lang.org](https://www.ruby-lang.org/))
2. **Clone the repo:**
   ```bash
   git clone https://github.com/BobaSipp/chronos.git
   cd chronos
   ```
3. **Run it:**
   ```bash
   ruby chronos.rb
   ```

No `Gemfile`, `bundle install`, or setup required.

## Usage

```
ruby chronos.rb [options]

Options:
  --hotspots   Launch directly into the Hotspots tab
  --info       Launch directly into the Info tab
  --help, -h   Show this help message
```

| Key | Action |
|-----|--------|
| `←` / `→` | Switch tabs |
| `q` | Quit |

## How it works

Chronos runs `git log --name-only --oneline` to parse commit history, groups the changed files, and ranks them by frequency. All rendering is done with raw ANSI escape codes — no curses or terminfo required.

## License

MIT
