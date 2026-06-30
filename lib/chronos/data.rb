# frozen_string_literal: true

module Chronos
  GitData = Struct.new(
    :hotspots, :total_commits, :branches, :repo_root, :authors,
    :file_types, :error,
    keyword_init: true
  )

  module_function

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
end
