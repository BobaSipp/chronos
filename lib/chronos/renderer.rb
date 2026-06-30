# frozen_string_literal: true

module Chronos
  module_function

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
    buf << "  #{ANSI::CYAN}\u250c#{'─' * width}\u2510#{ANSI::RESET}\n"
  end

  def bot_bar(width, buf)
    buf << "  #{ANSI::CYAN}\u2514#{'─' * width}\u2518#{ANSI::RESET}\n"
  end

  def sep_bar(cols, buf)
    buf << "  #{ANSI::CYAN}\u251c#{'─' * (cols - 4)}\u2524#{ANSI::RESET}\n"
  end

  def spacer_line(cols)
    "  #{ANSI::CYAN}\u2502#{ANSI::RESET}#{' ' * (cols - 4)}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n"
  end

  def title_line(cols, buf)
    title = "Chronos \u2014 Git Analytics v#{VERSION}"
    inner = cols - 4
    left = (inner - title.length) / 2
    right = inner - left - title.length
    buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}#{' ' * left}#{ANSI::BOLD}#{ANSI::GREEN}#{title}#{ANSI::RESET}#{' ' * right}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n"
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
    buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}  #{rendered}#{' ' * padding}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n"
  end

  def footer_line(cols, buf)
    hint = "#{ANSI::BOLD}\u2190#{ANSI::RESET} #{ANSI::BOLD}\u2192#{ANSI::RESET} tabs  #{ANSI::GREY}\u2022#{ANSI::RESET}  #{ANSI::BOLD}\u2191#{ANSI::RESET} #{ANSI::BOLD}\u2193#{ANSI::RESET} scroll  #{ANSI::GREY}\u2022#{ANSI::RESET}  #{ANSI::BOLD}q#{ANSI::RESET} quit"
    inner = cols - 4
    pad = inner - vis_len(hint) - 2
    pad = 0 if pad < 0
    buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}  #{hint}#{' ' * pad}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n"
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
    buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}  #{content}#{' ' * pad}  #{ANSI::CYAN}\u2502#{ANSI::RESET}\n"
  end

  def print_error(inner, msg, buf)
    buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n"
    msg.split("\n").each do |line|
      padded_line(inner, "#{ANSI::RED}#{ANSI::BOLD}#{line}#{ANSI::RESET}", buf)
    end
    buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n"
  end

  def render_hotspots(inner, data, scroll, lines, sort, buf)
    items = data.hotspots
    items = items.sort_by { |f, _| f.downcase } if sort == :name

    sort_tag = sort == :name ? " (A\u2013Z)" : ""
    padded_line(inner, "#{ANSI::BOLD}#{ANSI::YELLOW}Hotspots#{sort_tag}#{ANSI::RESET}", buf)
    buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n"

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
    remaining.times { buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n" }

    if need_scroll
      shown_to = [scroll + item_rows, items.size].min
      pct = (shown_to.to_f / items.size * 100).round
      padded_line(inner, "#{ANSI::GREY}\u2500\u2500 #{items.size} total, showing #{scroll + 1}\u2013#{shown_to} (#{pct}%) \u2500\u2500#{ANSI::RESET}", buf)
    end
  end

  def render_info(inner, data, buf)
    padded_line(inner, "#{ANSI::BOLD}#{ANSI::YELLOW}Repository Overview#{ANSI::RESET}", buf)
    buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n"

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

    buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n"

    padded_line(inner, "#{ANSI::BOLD}#{ANSI::YELLOW}File Types#{ANSI::RESET}", buf)
    buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n"

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
      buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n"
      padded_line(inner, "#{ANSI::GREY}  \u2026 and #{leftover} more extension(s)#{ANSI::RESET}", buf)
    end

    buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n"
  end

  def render_authors(inner, data, scroll, lines, buf)
    padded_line(inner, "#{ANSI::BOLD}#{ANSI::YELLOW}Authors#{ANSI::RESET}", buf)
    buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n"

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
    remaining.times { buf << "  #{ANSI::CYAN}\u2502#{ANSI::RESET}#{' ' * inner}#{ANSI::CYAN}\u2502#{ANSI::RESET}\n" }

    if need_scroll
      shown_to = [scroll + item_rows, items.size].min
      pct = (shown_to.to_f / items.size * 100).round
      padded_line(inner, "#{ANSI::GREY}\u2500\u2500 #{items.size} total, showing #{scroll + 1}\u2013#{shown_to} (#{pct}%) \u2500\u2500#{ANSI::RESET}", buf)
    end
  end
end
