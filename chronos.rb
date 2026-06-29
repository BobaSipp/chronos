#!/usr/bin/env ruby
# frozen_string_literal: true

require "io/console"
require "English"

module Chronos
  VERSION = "0.2.0"

  module ANSI
    BOLD    = "\e[1m"
    INVERT  = "\e[7m"
    GREEN   = "\e[32m"
    YELLOW  = "\e[33m"
    CYAN    = "\e[36m"
    RED     = "\e[31m"
    GREY    = "\e[90m"
    RESET   = "\e[0m"
    HOME    = "\e[H"
    HIDE_CURSOR = "\e[?25l"
    SHOW_CURSOR = "\e[?25h"
    ALT_BUF = "\e[?1049h"
    MAIN_BUF = "\e[?1049l"
  end

  TAB_LABELS = ["Hotspots", "Info"].freeze

  module_function

  def run(argv)
    if argv.include?("--help") || argv.include?("-h")
      print_usage
      return
    end
    start_tui
  end

  def start_tui
    trap("INT") { cleanup_and_exit(1) }

    print ANSI::ALT_BUF + ANSI::HIDE_CURSOR

    current_tab = 0
    data_cache = nil

    loop do
      _rows, cols = IO.console.winsize
      data_cache ||= collect_git_data
      frame = render(cols, current_tab, data_cache)
      print ANSI::HOME + frame

      case read_key
      when :left  then current_tab = [current_tab - 1, 0].max
      when :right then current_tab = [current_tab + 1, TAB_LABELS.size - 1].min
      when :quit  then break
      end
    end
  ensure
    print ANSI::SHOW_CURSOR + ANSI::MAIN_BUF
  end

  def read_key
    c = STDIN.getch
    return :quit if c == "q"

    if c == "\e" && IO.select([STDIN], nil, nil, 0.1)
      seq = STDIN.getch
      return :unknown unless seq == "["

      arrow = STDIN.getch
      case arrow
      when "D" then return :left
      when "C" then return :right
      end
    end
    :unknown
  end

  # --- Data ---

  GitData = Struct.new(:hotspots, :total_commits, :branches, :repo_root, :error, keyword_init: true)

  def collect_git_data
    unless system("git rev-parse --git-dir 2> nul")
      return GitData.new(error: "Not a Git repository.\nRun `git init` first.")
    end

    log_output = IO.popen(["git", "log", "--name-only", "--oneline"], &:read)
    return GitData.new(error: "Failed to retrieve git log.") unless $CHILD_STATUS.success?

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

    total_commits = log_output.each_line.count { |l| l.match?(/^[0-9a-f]{7,}\s/) }
    branches = branches_output.each_line.map(&:strip).reject(&:empty?)

    GitData.new(hotspots: hotspots, total_commits: total_commits,
                branches: branches, repo_root: repo_root)
  end

  # --- Rendering ---

  def render(cols, tab, data)
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

    content_area(inner, tab, data, out)

    out << spacer_line(cols)
    sep_bar(cols, out)
    out << spacer_line(cols)
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
    title = "Chronos — Git Analytics v#{VERSION}"
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
    hint = "Press #{ANSI::BOLD}←#{ANSI::RESET} #{ANSI::BOLD}→#{ANSI::RESET} to switch tabs  #{ANSI::GREY}•#{ANSI::RESET}  #{ANSI::BOLD}q#{ANSI::RESET} to quit"
    inner = cols - 4
    pad = inner - vis_len(hint) - 2
    pad = 0 if pad < 0
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}  #{hint}#{' ' * pad}#{ANSI::CYAN}│#{ANSI::RESET}\n"
  end

  def content_area(inner, tab, data, buf)
    if data.error
      print_error(inner, data.error, buf)
      return
    end

    case tab
    when 0 then render_hotspots(inner, data, buf)
    when 1 then render_info(inner, data, buf)
    end
  end

  # --- Helpers ---

  def vis_len(str)
    str.gsub(/\e\[[0-9;]*[a-zA-Z]/, "").length
  end

  def padded_line(inner, content, buf)
    pad = inner - vis_len(content)
    pad = 0 if pad < 0
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}  #{content}#{' ' * pad}  #{ANSI::CYAN}│#{ANSI::RESET}\n"
  end

  # --- Error ---

  def print_error(inner, msg, buf)
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"
    msg.split("\n").each do |line|
      padded_line(inner, "#{ANSI::RED}#{ANSI::BOLD}#{line}#{ANSI::RESET}", buf)
    end
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"
  end

  # --- Hotspots Tab ---

  def render_hotspots(inner, data, buf)
    padded_line(inner, "#{ANSI::BOLD}#{ANSI::YELLOW}Top 5 Hotspots#{ANSI::RESET}", buf)
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"

    top = data.hotspots.take(5)
    max_count = top.map { |_f, c| c }.max || 1

    top.each_with_index do |(file, count), idx|
      label = "#{ANSI::BOLD}#{idx + 1}.#{ANSI::RESET} #{file}"
      max_raw = inner - 6
      max_raw = 1 if max_raw < 1
      bar_len = (count.to_f / max_count * max_raw).round
      bar = ANSI::GREEN + "█" * bar_len + ANSI::RESET
      count_str = "#{ANSI::YELLOW}#{count}#{ANSI::RESET}"
      line_content = "#{label}#{' ' * 2}#{bar}#{' ' * 1}#{count_str}"
      padded_line(inner, line_content, buf)
    end

    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"
  end

  # --- Info Tab ---

  def render_info(inner, data, buf)
    padded_line(inner, "#{ANSI::BOLD}#{ANSI::YELLOW}Repository Overview#{ANSI::RESET}", buf)
    buf << "  #{ANSI::CYAN}│#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}│#{ANSI::RESET}\n"

    rows_info = [
      ["Directory", data.repo_root],
      ["Commits",   data.total_commits.to_s],
      ["Branches",  data.branches.join(", ")]
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
  end

  def cleanup_and_exit(code)
    print ANSI::SHOW_CURSOR + ANSI::MAIN_BUF
    exit code
  end

  def print_usage
    puts <<~USAGE
      #{ANSI::BOLD}Chronos#{ANSI::RESET} #{VERSION} — Git repository analytics TUI

      Usage: ruby chronos.rb [options]

      Options:
        --hotspots   Launch directly into the Hotspots tab
        --info       Launch directly into the Info tab
        --help, -h   Show this help message
    USAGE
  end
end

Chronos.run(ARGV)
