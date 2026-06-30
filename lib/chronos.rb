# frozen_string_literal: true

require "io/console"
require "English"

require_relative "chronos/version"
require_relative "chronos/ansi"
require_relative "chronos/data"
require_relative "chronos/cli"
require_relative "chronos/tui"
require_relative "chronos/renderer"

module Chronos
  TAB_LABELS = ["Hotspots", "Info", "Authors"].freeze

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
end
