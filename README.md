# Chronos

**Lightweight terminal-based Git repository analytics dashboard.**

Chronos is a Ruby TUI that gives you a live, interactive overview of your Git
repository's commit activity. No external dependencies, no bundler, no fuss.

## Installation

### Via GitHub Packages

```bash
# Add GitHub Packages as a gem source
gem sources --add https://rubygems.pkg.github.com/BobaSipp

# Install
gem install chronos
```

> Requires a GitHub [personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) with `read:packages` scope. Create `~/.gem/credentials`:
> ```
> ---
> :github: Bearer YOUR_TOKEN
> ```
> Then `chmod 0600 ~/.gem/credentials`.

### From source

```bash
git clone https://github.com/BobaSipp/chronos.git
cd chronos
gem build chronos.gemspec
gem install chronos-*.gem
```

Or run directly without installing:

```bash
git clone https://github.com/BobaSipp/chronos.git
cd chronos
ruby bin/chronos
```

Run it from any Git repository directory.

## What It Looks Like

```
Chronos v0.1b — Git Analytics

  [Hotspots]  Info  Authors

Hotspots
  1. src/main.rb          34
  2. src/utils.rb         12
  3. lib/helper.rb         8
  4. tests/main_test.rb    5
  5. src/cli.rb            3

   TAB next tab  j/k scroll  q quit
```

Three tabs: **Hotspots** (most-changed files), **Info** (repo overview + file-type
breakdown), and **Authors** (top contributors). Press `TAB` to cycle tabs, `j`/`k`
to scroll, `q` to quit.

## Features

- **Three tabs** — Hotspots, Info, Authors with Tab key switching
- **Scrollable lists** — j/k keys navigate long lists
- **Auto-refresh** (`--watch`) — re-collects data every 2 seconds
- **JSON export** (`--json`) — outputs all data as JSON for scripting
- **Sort options** — `--sort count` (default) or `--sort name`
- **Zero dependencies** — uses only Ruby stdlib (`io/console`, `English`, `json`)
- **Cross-platform** — runs on Linux, macOS, Windows (anywhere Ruby runs)
- **Installable gem** — `gem install chronos`, then run `chronos` from any repo

## Usage

```
chronos [options]

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
| `Tab` | Next tab |
| `j` / `k` | Scroll down / up |
| `q` | Quit |

## Project Structure

```
chronos/
  bin/chronos           # Executable entry point
  lib/
    chronos.rb          # Library entry point
    chronos/
      version.rb        # VERSION constant
      ansi.rb           # ANSI escape codes
      data.rb           # GitData struct & data collection
      cli.rb            # CLI option parsing & JSON export
      tui.rb            # TUI main loop & keyboard input
      renderer.rb       # All rendering logic
  dcs/                  # Documentation website
  LICENSE
  README.md
```

## How It Works

Chronos runs `git log --name-only --oneline` to parse commit history, groups
changed files, and ranks them by frequency. Author stats come from
`git log --format=%an`. All rendering is done with raw ANSI escape codes.
The application is organized into focused modules under `lib/chronos/`.

## License

MIT
