#!/usr/bin/env ruby
# frozen_string_literal: true

# Chronos — Git repository analytics CLI
# Phase 1: Hotspot analysis via --hotspots

module Chronos
  BOLD   = "\e[1m"
  GREEN  = "\e[32m"
  YELLOW = "\e[33m"
  RED    = "\e[31m"
  RESET  = "\e[0m"

  module_function

  def run(argv)
    if argv.include?("--hotspots")
      hotspots
    else
      print_usage
    end
  end

  def hotspots
    log_output = fetch_git_log
    files = parse_log(log_output)
    sorted = rank_files(files)
    print_top_five(sorted)
  rescue ChronosError => e
    puts "#{RED}#{BOLD}Error:#{RESET}#{RED} #{e.message}#{RESET}"
    exit 1
  end

  def fetch_git_log
    unless system("git rev-parse --git-dir 2> nul")
      raise NotAGitRepositoryError,
        "This does not appear to be a Git repository.\n" \
        "Run `git init` first, or navigate into a Git-tracked project."
    end

    output = `git log --name-only --oneline`
    unless $?.success?
      raise ChronosError, "Failed to retrieve git log."
    end

    output
  end

  def parse_log(raw)
    raw
      .each_line
      .map(&:strip)
      .reject { |line| line.empty? || line.match?(/^[0-9a-f]{7,}\s/) }
      .group_by(&:itself)
      .transform_values(&:count)
  end

  def rank_files(files)
    files
      .sort_by { |_file, count| -count }
  end

  def print_top_five(sorted)
    top = sorted.take(5)

    puts "\n  #{BOLD}#{GREEN}Hotspot Analysis#{RESET}\n"
    puts "  #{'─' * 40}\n\n"

    top.each_with_index do |(file, count), idx|
      puts "  #{idx + 1}. #{GREEN}#{BOLD}#{file}#{RESET}  #{YELLOW}(#{count} changes)#{RESET}"
    end

    puts "\n  #{'─' * 40}\n"
    puts "  Total files tracked: #{sorted.size}\n\n"
  end

  def print_usage
    puts <<~USAGE
      #{BOLD}Usage:#{RESET} ruby chronos.rb --hotspots

      Options:
        --hotspots   Show the top 5 most frequently modified files
    USAGE
  end
end

ChronosError      = Class.new(StandardError)
NotAGitRepositoryError = Class.new(ChronosError)

Chronos.run(ARGV)
