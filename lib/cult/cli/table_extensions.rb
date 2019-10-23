require 'terminal-table'

# This extends Terminal::Table to do plain tab-separated columns if Rainbow
# is disabled, which roughly translates to isatty?

module Cult
  module TableExtensions
    def render_plain
      rows.map do |row|
        row.cells.map(&:value).join("\t")
      end.join("\n")
    end

    def render
      Rainbow.enabled ? super : render_plain
    end

    alias_method :to_s, :render

    ::Terminal::Table.prepend(self)
  end
end
