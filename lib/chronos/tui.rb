# frozen_string_literal: true

module Chronos
  module_function

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

  def tab_item_count(tab, data)
    case tab
    when 0 then (data&.hotspots || []).size
    when 2 then (data&.authors || []).size
    else 0
    end
  end

  def cleanup_and_exit(code)
    print ANSI::SHOW_CURSOR + ANSI::MAIN_BUF
    exit code
  end
end
