# frozen_string_literal: true

module Chronos
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
end
