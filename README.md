# Chronos

**Lightweight terminal-based Git repository analytics dashboard.**

Chronos is a single-file Ruby TUI that gives you a live, interactive overview of your Git repository's commit activity — no external dependencies, no bundler, no fuss.

## Features

- **Hotspots tab** — Most frequently changed files, ranked by commit count with visual bar charts (scrollable with ↑/↓)
- **Authors tab** — Top contributors, ranked by commit count with bar charts (scrollable)
- **Info tab** — Repository overview: directory path, total commits, branches, author count, and file-type breakdown with bar charts
- **Scrollable lists** — ↑/↓ to scroll through long lists
- **Auto-refresh** (`--watch`) — Re-collect data every 2 seconds
- **JSON export** (`--json`) — Dump all data as JSON for scripting
- **Sort options** — Sort hotspots by commit count or alphabetically
- **No dependencies** — Uses only Ruby stdlib (`io/console`, `English`, `json`)
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
  --hotspots    Launch directly into the Hotspots tab
  --info        Launch directly into the Info tab
  --authors     Launch directly into the Authors tab
  --watch       Auto-refresh data every 2 seconds
  --sort count  Sort hotspots by commit count (default)
  --sort name   Sort hotspots alphabetically
  --json        Export data as JSON and exit
  --help, -h    Show this help message
```

| Key | Action |
|-----|--------|
| `←` / `→` | Switch tabs |
| `↑` / `↓` | Scroll through lists |
| `q` | Quit |

## Example

```bash
# Launch TUI
ruby chronos.rb

# Start on a specific tab
ruby chronos.rb --authors

# Auto-refresh every 2 seconds
ruby chronos.rb --watch

# Sort hotspots alphabetically
ruby chronos.rb --sort name

# Export data as JSON
ruby chronos.rb --json
```

## How it works

Chronos runs `git log --name-only --oneline` to parse commit history, groups the changed files, and ranks them by frequency. Author stats come from `git log --format=%an`. All rendering is done with raw ANSI escape codes — no curses or terminfo required.

## License

MIT
