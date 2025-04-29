module CliTester
  # Provides cross-platform shell argument escaping utilities.
  # Handles differences between POSIX shells (bash/zsh) and Windows cmd.exe.
  #
  # Example POSIX escaping:
  #   escape("file with spaces") => "'file with spaces'"
  #   escape("don't") => "'don'\\''t'"
  #
  # Example Windows escaping:
  #   escape("dir with spaces") => "\"dir with spaces\""
  #   escape("quotes\"here") => "\"quotes\\\"here\""
  module Shell
    # Escapes a single argument for safe shell interpolation.
    # @param argument [String] The argument to escape
    # @return [String] Safe to interpolate in `sh -c "..."` (POSIX) or `cmd /c "..."` (Windows)
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
        # POSIX escaping (simplified):
        return "''" if argument.empty?
        "'#{argument.gsub(/'/, "'\\\\''")}'"
      {% end %}
    end

    # TODO: Add helper for constructing full commands safely?
    # def self.build_command(executable : String, args : Array(String)) : String
    #   ...
    # end
  end
end
