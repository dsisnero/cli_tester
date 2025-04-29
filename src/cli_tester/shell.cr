module CliTester
  # Provides cross-platform shell utilities.
  module Shell
    # Escapes a string for safe use as a single argument in a shell command.
    # Handles differences between POSIX shells (like bash, zsh) and Windows cmd.exe.
    #
    # NOTE: This is a basic implementation. Robust shell escaping can be complex.
    # Consider using libraries designed for this if complex arguments are needed.
    #
    # @param argument [String] The argument string to escape.
    # @return [String] The escaped argument, suitable for interpolation into a command string.
    def self.escape(argument : String) : String
      {% if flag?(:win32) %}
        # Windows cmd.exe escaping:
        # - Surround with double quotes.
        # - Escape internal double quotes with a backslash (\").
        # - Backslashes preceding a double quote must be escaped (\\").
        # - Other backslashes are generally fine unless followed by a quote.
        # - Percent signs need doubling (%%) if variable expansion is undesired.
        # This is a simplified version focusing on quotes and backslashes near quotes.
        escaped = argument.gsub(/\\*(")/) do |match|
          # Escape backslashes preceding a quote, then escape the quote
          match[0].gsub("\\", "\\\\") + "\\\""
        end
        "\"#{escaped}\""
      {% else %}
        # POSIX sh/bash/zsh escaping:
        # - Surround with single quotes.
        # - Escape internal single quotes: replace ' with '\'' (end quote, escaped quote, start quote).
        "'#{argument.gsub("'", "'\\''")}'"
      {% end %}
    end

    # TODO: Add helper for constructing full commands safely?
    # def self.build_command(executable : String, args : Array(String)) : String
    #   ...
    # end
  end
end
