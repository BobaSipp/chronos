# frozen_string_literal: true

module Chronos
  module_function

  def render(tab, data, scroll, content_lines, sort)
    out = +""

    out << "#{ANSI::BOLD}#{ANSI::GREEN}Chronos v#{VERSION}#{ANSI::RESET} \u2014 Git Analytics\n"

    out << "  "
    TAB_LABELS.each_with_index do |label, i|
      if i == tab
        out << "#{ANSI::INVERT} #{label} #{ANSI::RESET}"
      else
        out << " #{label} "
      end
      out << " " unless i == TAB_LABELS.size - 1
    end
    out << "\n\n"

    content_data(tab, data, scroll, content_lines, sort, out)

    out << "\n#{ANSI::GREY}TAB next tab  j/k scroll  q quit#{ANSI::RESET}\n"

    out
  end

  def content_data(tab, data, scroll, content_lines, sort, buf)
    if data&.error
      buf << "#{ANSI::RED}#{ANSI::BOLD}#{data.error}#{ANSI::RESET}\n"
      return
    end

    case tab
    when 0 then render_hotspots(data, scroll, content_lines, sort, buf)
    when 1 then render_info(data, buf)
    when 2 then render_authors(data, scroll, content_lines, buf)
    end
  end

  def render_hotspots(data, scroll, lines, sort, buf)
    items = data.hotspots
    items = items.sort_by { |f, _| f.downcase } if sort == :name

    sort_tag = sort == :name ? " (A-Z)" : ""
    buf << "#{ANSI::BOLD}#{ANSI::YELLOW}Hotspots#{sort_tag}#{ANSI::RESET}\n"

    max_count = items.map { |_f, c| c }.max || 1
    label_w = [items.map { |f, _| f.length }.max || 1, 30].min
    gap = 3

    item_rows = lines - 1
    item_rows = 1 if item_rows < 1
    slice = items.slice(scroll, item_rows) || []

    slice.each_with_index do |(file, count), idx|
      global_idx = scroll + idx + 1
      num = "#{global_idx}."
      name = file.length > label_w ? "#{file[0, label_w - 1]}…" : file
      buf << "  #{ANSI::BOLD}#{num}#{ANSI::RESET} #{name}#{' ' * (label_w - name.length)}#{' ' * gap}#{ANSI::YELLOW}#{count}#{ANSI::RESET}\n"
    end

    if items.size > item_rows
      shown_to = [scroll + item_rows, items.size].min
      buf << "#{ANSI::GREY}#{items.size} total, showing #{scroll + 1}-#{shown_to}#{ANSI::RESET}\n"
    end
  end

  def render_info(data, buf)
    buf << "#{ANSI::BOLD}#{ANSI::YELLOW}Repository Overview#{ANSI::RESET}\n"

    rows_info = [
      ["Directory", data.repo_root],
      ["Commits",   data.total_commits.to_s],
      ["Branches",  data.branches.join(", ")],
      ["Authors",   data.authors.size.to_s],
      ["Files changed", data.hotspots.size.to_s],
    ]

    label_w = rows_info.map { |r| r[0].length }.max

    rows_info.each do |label, value|
      val = value.length > 60 ? "#{value[0, 57]}..." : value
      buf << "  #{ANSI::BOLD}#{label.ljust(label_w)}:#{ANSI::RESET} #{val}\n"
    end

    buf << "\n#{ANSI::BOLD}#{ANSI::YELLOW}File Types#{ANSI::RESET}\n"
    ext_label_w = 12
    data.file_types.first(8).each do |ext, count|
      display_ext = ext.empty? ? "(none)" : ext
      buf << "  #{display_ext.ljust(ext_label_w)} #{count}\n"
    end

    leftover = data.file_types.size - 8
    if leftover > 0
      buf << "  #{ANSI::GREY}...#{leftover} more#{ANSI::RESET}\n"
    end
  end

  def render_authors(data, scroll, lines, buf)
    buf << "#{ANSI::BOLD}#{ANSI::YELLOW}Authors#{ANSI::RESET}\n"

    items = data.authors
    label_w = [items.map { |a, _| a.length }.max || 1, 25].min
    gap = 3

    item_rows = lines - 1
    item_rows = 1 if item_rows < 1
    slice = items.slice(scroll, item_rows) || []

    slice.each_with_index do |(author, count), idx|
      global_idx = scroll + idx + 1
      num = "#{global_idx}."
      name = author.length > label_w ? "#{author[0, label_w - 1]}…" : author
      buf << "  #{ANSI::BOLD}#{num}#{ANSI::RESET} #{name}#{' ' * (label_w - name.length)}#{' ' * gap}#{ANSI::YELLOW}#{count}#{ANSI::RESET}\n"
    end

    if items.size > item_rows
      shown_to = [scroll + item_rows, items.size].min
      buf << "#{ANSI::GREY}#{items.size} total, showing #{scroll + 1}-#{shown_to}#{ANSI::RESET}\n"
    end
  end
end
