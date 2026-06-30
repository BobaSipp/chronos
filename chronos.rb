#!/usr/bin/env ruby
# frozen_string_literal: true

require "io/console"
require "English"
require "json"

module Chronos
  VERSION = "0.3.0"

  module ANSI
    BOLD    = "\e[1m"
    INVERT  = "\e[7m"
    GREEN   = "\e[32m"
    YELLOW  = "\e[33m"
    CYAN    = "\e[36m"
    RED     = "\e[31m"
    GREY    = "\e[90m"
    MAGENTA = "\e[35m"
    BLUE    = "\e[34m"
    RESET   = "\e[0m"
    HOME    = "\e[H"
    HIDE_CURSOR = "\e[?25l"
    SHOW_CURSOR = "\e[?25h"
    ALT_BUF = "\e[?1049h"
    MAIN_BUF = "\e[?1049l"
  end

  TAB_LABELS = ["Hotspots", "Info", "Authors"].freeze

  GitData = Struct.new(
    :hotspots, :total_commits, :branches, :repo_root, :authors,
    :file_types, :error,
    keyword_init: true
  )

  module_function

  def run(argv)
    opts = parse_opts(argv)
    return if opts[:help]

    if opts[:json]
      dump_json
      return
    end

    start_tui(opts)
  end

  def parse_opts(argv)
    opts = { tab: 0, watch: false, sort: :count, help: false, json: false }

    opts[:tab] = 0 if argv.include?("--hotspots")
    opts[:tab] = 1 if argv.include?("--info")
    opts[:tab] = 2 if argv.include?("--authors")
    opts[:watch] = true if argv.include?("--watch")
    opts[:json] = true if argv.include?("--json")

    if argv.include?("--sort")
      idx = argv.index("--sort")
      val = argv[idx + 1]
      opts[:sort] = val.to_sym if val && %w[count name].include?(val)
    end

    opts[:help] = true if argv.include?("--help") || argv.include?("-h")
    opts
  end

  def start_tui(opts)
    trap("INT") { cleanup_and_exit(1) }

    print ANSI::ALT_BUF + ANSI::HIDE_CURSOR
    print ANSI::HOME + "  #{ANSI::BOLD}Gathering repository data...#{ANSI::RESET}\n"
    data_cache = collect_git_data

    current_tab = opts[:tab]
    scroll = 0

    loop do
      rows, cols = IO.console.winsize
      content_lines = [rows - 11, 1].max
      frame = render(cols, rows, current_tab, data_cache, scroll, content_lines, opts[:sort])
      print ANSI::HOME + frame

      case read_key(opts[:watch] ? 2 : nil)
      when :left
        current_tab = [current_tab - 1, 0].max
        scroll = 0
      when :right
        current_tab = [current_tab + 1, TAB_LABELS.size - 1].min
        scroll = 0
      when :up
        max_items = tab_item_count(current_tab, data_cache)
        visible = content_lines - 2
        max_scroll = [max_items - visible, 0].max
        scroll = scroll - 1 if scroll > 0
      when :down
        max_items = tab_item_count(current_tab, data_cache)
        visible = content_lines - 2
        max_scroll = [max_items - visible, 0].max
        scroll = scroll + 1 if scroll < max_scroll
      when :timeout
        print ANSI::HOME + "  #{ANSI::BOLD}Refreshing repository data...#{ANSI::RESET}\n"
        data_cache = collect_git_data
        scroll = 0
      when :quit then break
      end
    end
  ensure
    print ANSI::SHOW_CURSOR + ANSI::MAIN_BUF
  end

  def tab_item_count(tab, data)
    case tab
    when 0 then (data&.hotspots || []).size
    when 2 then (data&.authors || []).size
    else 0
    end
  end

  def read_key(timeout = nil)
    if timeout
      ready = IO.select([STDIN], nil, nil, timeout)
      return :timeout unless ready
    end

    c = STDIN.getch
    return :quit if c == "q"

    if c == "\e" && IO.select([STDIN], nil, nil, 0.1)
      seq = STDIN.getch
      return :unknown unless seq == "["

      case STDIN.getch
      when "A" then return :up
      when "B" then return :down
      when "D" then return :left
      when "C" then return :right
      end
    end
    :unknown
  end

  def collect_git_data
    unless system("git rev-parse --git-dir 2> nul")
      return GitData.new(error: "Not a Git repository.\nRun `git init` first.")
    end

    log_output = IO.popen(["git", "log", "--name-only", "--oneline"], &:read)
    return GitData.new(error: "Failed to retrieve git log.") unless $CHILD_STATUS.success?

    author_output = IO.popen(["git", "log", "--format=%an"], &:read)
    branches_output = IO.popen(["git", "branch", "--list"], &:read)
    repo_root = IO.popen(["git", "rev-parse", "--show-toplevel"], &:read).strip

    files = log_output
      .each_line
      .map(&:strip)
      .reject { |l| l.empty? || l.match?(/^[0-9a-f]{7,}\s/) }

    hotspots = files
      .group_by(&:itself)
      .transform_values(&:count)
      .sort_by { |_f, c| -c }

    file_types = files
      .group_by { |f| f.include?(".") ? File.extname(f).downcase : "(none)" }
      .transform_values(&:count)
      .sort_by { |_e, c| -c }

    total_commits = log_output.each_line.count { |l| l.match?(/^[0-9a-f]{7,}\s/) }
    branches = branches_output.each_line.map(&:strip).reject(&:empty?)

    authors = author_output
      .each_line
      .map(&:strip)
      .reject(&:empty?)
      .group_by(&:itself)
      .transform_values(&:count)
      .sort_by { |_a, c| -c }

    GitData.new(
      hotspots: hotspots,
      total_commits: total_commits,
      branches: branches,
      repo_root: repo_root,
      authors: authors,
      file_types: file_types
    )
  end

  def dump_json
    data = collect_git_data
    if data.error
      puts JSON.pretty_generate({ error: data.error })
      return
    end

    puts JSON.pretty_generate({
      version: VERSION,
      repo_root: data.repo_root,
      total_commits: data.total_commits,
      branches: data.branches,
      hotspots: data.hotspots.map { |f, c| { file: f, commits: c } },
      authors: data.authors.map { |a, c| { author: a, commits: c } },
      file_types: data.file_types.map { |ext, count| { extension: ext, files: count } }
    })
  end

  def render(cols, rows, tab, data, scroll, content_lines, sort)
    out = +""
    inner = cols - 4
    inner = 10 if inner < 10

    top_bar(inner, out)
    out << spacer_line(cols)
    title_line(cols, out)
    out << spacer_line(cols)
    tab_bar(cols, tab, out)
    sep_bar(cols, out)
    out << spacer_line(cols)

    content_area(inner, tab, data, scroll, content_lines, sort, out)

    out << spacer_line(cols)
    sep_bar(cols, out)
    out << spacer_line(cols)
    footer_line(cols, out)
    bot_bar(inner, out)
    out
  end

  def top_bar(width, buf)
    buf << "  #{ANSI::CYAN}┌#{'─' * width}┐#{ANSI::RESET}\n"
  end

  def bot_bar(width, buf)
    buf << "  #{ANSI::CYAN}└#{'─' * width}┘#{ANSI::RESET}\n"
  end

  def sep_bar(cols, buf)
    buf << "  #{ANSI::CYAN}├#{'─' * (cols - 4)}┤#{ANSI::RESET}\n"
  end

  def spacer_line(cols)
    "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * (cols - 4)}#{ANSI::CYAN}│#{ANSI::RESET}\n"
  end

  def title_line(cols, buf)
    title = "Chronos \u2014 Git Analytics v#{VERSION}"
    inner = cols - 4
    left = (inner - title.length) / 2
    right = inner - left - title.length
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * left}#{ANSI::BOLD}#{ANSI::GREEN}#{title}#{ANSI::RESET}#{' ' * right}#{ANSI::CYAN}│#{ANSI::RESET}\n"
  end

  def tab_bar(cols, active, buf)
    inner = cols - 4
    tabs = TAB_LABELS.each_with_index.map do |label, i|
      if i == active
        "#{ANSI::INVERT} #{label} #{ANSI::RESET}"
      else
        " #{label} "
      end
    end
    rendered = tabs.join("  ")
    padding = inner - vis_len(rendered) - 2
    padding = 0 if padding < 0
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}  #{rendered}#{' ' * padding}#{ANSI::CYAN}│#{ANSI::RESET}\n"
  end

  def footer_line(cols, buf)
    hint = "#{ANSI::BOLD}\u2190#{ANSI::RESET} #{ANSI::BOLD}\u2192#{ANSI::RESET} tabs  #{ANSI::GREY}\u2022#{ANSI::RESET}  #{ANSI::BOLD}\u2191#{ANSI::RESET} #{ANSI::BOLD}\u2193#{ANSI::RESET} scroll  #{ANSI::GREY}\u2022#{ANSI::RESET}  #{ANSI::BOLD}q#{ANSI::RESET} quit"
    inner = cols - 4
    pad = inner - vis_len(hint) - 2
    pad = 0 if pad < 0
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}  #{hint}#{' ' * pad}#{ANSI::CYAN}│#{ANSI::RESET}\n"
  end

  def content_area(inner, tab, data, scroll, lines, sort, buf)
    if data&.error
      print_error(inner, data.error, buf)
      return
    end

    case tab
    when 0 then render_hotspots(inner, data, scroll, lines, sort, buf)
    when 1 then render_info(inner, data, buf)
    when 2 then render_authors(inner, data, scroll, lines, buf)
    end
  end

  def vis_len(str)
    str.gsub(/\e\[[0-9;]*[a-zA-Z]/, "").length
  end

  def padded_line(inner, content, buf)
    pad = inner - vis_len(content)
    pad = 0 if pad < 0
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}  #{content}#{' ' * pad}  #{ANSI::CYAN}│#{ANSI::RESET}\n"
  end

  def print_error(inner, msg, buf)
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"
    msg.split("\n").each do |line|
      padded_line(inner, "#{ANSI::RED}#{ANSI::BOLD}#{line}#{ANSI::RESET}", buf)
    end
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"
  end

  def render_hotspots(inner, data, scroll, lines, sort, buf)
    items = data.hotspots
    items = items.sort_by { |f, _| f.downcase } if sort == :name

    sort_tag = sort == :name ? " (A\u2013Z)" : ""
    padded_line(inner, "#{ANSI::BOLD}#{ANSI::YELLOW}Hotspots#{sort_tag}#{ANSI::RESET}", buf)
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"

    need_scroll = items.size > lines - 2
    item_rows = need_scroll ? lines - 4 : lines - 3
    item_rows = 0 if item_rows < 0

    max_count = items.map { |_f, c| c }.max || 1
    max_bar = inner - 10
    max_bar = 1 if max_bar < 1

    slice = items.slice(scroll, item_rows) || []
    slice.each_with_index do |(file, count), idx|
      global_idx = scroll + idx + 1
      label = "#{ANSI::BOLD}#{global_idx}.#{ANSI::RESET} #{file}"
      bar_len = (count.to_f / max_count * max_bar).round
      bar = ANSI::GREEN + "\u2588" * bar_len + ANSI::RESET
      count_str = "#{ANSI::YELLOW}#{count}#{ANSI::RESET}"
      padded_line(inner, "#{label}#{' ' * 2}#{bar}#{' ' * 1}#{count_str}", buf)
    end

    filled = 2 + slice.size
    remaining = lines - filled - (need_scroll ? 1 : 0)
    remaining.times { buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n" }

    if need_scroll
      shown_to = [scroll + item_rows, items.size].min
      pct = (shown_to.to_f / items.size * 100).round
      padded_line(inner, "#{ANSI::GREY}\u2500\u2500 #{items.size} total, showing #{scroll + 1}\u2013#{shown_to} (#{pct}%) \u2500\u2500#{ANSI::RESET}", buf)
    end
  end

  def render_info(inner, data, buf)
    padded_line(inner, "#{ANSI::BOLD}#{ANSI::YELLOW}Repository Overview#{ANSI::RESET}", buf)
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"

    rows_info = [
      ["Directory", data.repo_root],
      ["Commits",   data.total_commits.to_s],
      ["Branches",  data.branches.join(", ")],
      ["Authors",   data.authors.size.to_s],
      ["Files changed", data.hotspots.size.to_s],
    ]

    label_w = rows_info.map { |r| r[0].length }.max

    rows_info.each do |label, value|
      display = "#{ANSI::BOLD}#{label.ljust(label_w)}:#{ANSI::RESET} #{ANSI::GREEN}#{value}#{ANSI::RESET}"
      max_val_width = inner - label_w - 3
      if vis_len(display) > inner
        value = value[0, [max_val_width - 3, 0].max] + "..."
        display = "#{ANSI::BOLD}#{label.ljust(label_w)}:#{ANSI::RESET} #{ANSI::GREEN}#{value}#{ANSI::RESET}"
      end
      padded_line(inner, display, buf)
    end

    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"

    padded_line(inner, "#{ANSI::BOLD}#{ANSI::YELLOW}File Types#{ANSI::RESET}", buf)
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"

    max_type_count = data.file_types.map { |_e, c| c }.max || 1
    max_type_bar = inner - 16
    max_type_bar = 1 if max_type_bar < 1

    data.file_types.first(8).each do |ext, count|
      bar_len = (count.to_f / max_type_count * max_type_bar).round
      bar = ANSI::MAGENTA + "\u2588" * bar_len + ANSI::RESET
      display_ext = ext.empty? ? "(none)" : ext
      padded_line(inner, "#{ANSI::BOLD}#{display_ext}#{ANSI::RESET}#{' ' * (10 - display_ext.length)}#{bar}#{' ' * 1}#{ANSI::YELLOW}#{count}#{ANSI::RESET}", buf)
    end

    leftover = data.file_types.size - 8
    if leftover > 0
      buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"
      padded_line(inner, "#{ANSI::GREY}  \u2026 and #{leftover} more extension(s)#{ANSI::RESET}", buf)
    end

    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"
  end

  def render_authors(inner, data, scroll, lines, buf)
    padded_line(inner, "#{ANSI::BOLD}#{ANSI::YELLOW}Authors#{ANSI::RESET}", buf)
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"

    items = data.authors
    need_scroll = items.size > lines - 2
    item_rows = need_scroll ? lines - 4 : lines - 3
    item_rows = 0 if item_rows < 0

    max_count = items.map { |_a, c| c }.max || 1
    max_bar = inner - 10
    max_bar = 1 if max_bar < 1

    slice = items.slice(scroll, item_rows) || []
    slice.each_with_index do |(author, count), idx|
      global_idx = scroll + idx + 1
      label = "#{ANSI::BOLD}#{global_idx}.#{ANSI::RESET} #{author}"
      bar_len = (count.to_f / max_count * max_bar).round
      bar = ANSI::BLUE + "\u2588" * bar_len + ANSI::RESET
      count_str = "#{ANSI::YELLOW}#{count}#{ANSI::RESET}"
      padded_line(inner, "#{label}#{' ' * 2}#{bar}#{' ' * 1}#{count_str}", buf)
    end

    filled = 2 + slice.size
    remaining = lines - filled - (need_scroll ? 1 : 0)
    remaining.times { buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n" }

    if need_scroll
      shown_to = [scroll + item_rows, items.size].min
      pct = (shown_to.to_f / items.size * 100).round
      padded_line(inner, "#{ANSI::GREY}\u2500\u2500 #{items.size} total, showing #{scroll + 1}\u2013#{shown_to} (#{pct}%) \u2500\u2500#{ANSI::RESET}", buf)
    end
  end

  def cleanup_and_exit(code)
    print ANSI::SHOW_CURSOR + ANSI::MAIN_BUF
    exit code
  end

  def print_usage
    puts <<~USAGE
      #{ANSI::BOLD}Chronos#{ANSI::RESET} #{VERSION} \u2014 Git repository analytics TUI

      Usage: ruby chronos.rb [options]

      Options:
        --hotspots    Launch directly into the Hotspots tab
        --info        Launch directly into the Info tab
        --authors     Launch directly into the Authors tab
        --watch       Auto-refresh data every 2 seconds
        --sort count  Sort hotspots by commit count (default)
        --sort name   Sort hotspots alphabetically
        --json        Export data as JSON and exit
        --help, -h    Show this help message
    USAGE
  end
end

Chronos.run(ARGV)
