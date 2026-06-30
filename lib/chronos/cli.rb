# frozen_string_literal: true

require "json"

module Chronos
  module_function

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

  def print_usage
    puts <<~USAGE
      #{ANSI::BOLD}Chronos#{ANSI::RESET} #{VERSION} \u2014 Git repository analytics TUI

      Usage: chronos [options]

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
end
