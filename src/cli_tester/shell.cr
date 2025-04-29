module CliTester
  # Provides cross-platform shell utilities including:
  # - Argument escaping
  # - XDG environment configuration
  # - Platform-specific command formatting
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

    # Constructs a command that safely sets XDG_CONFIG_HOME before
    # execution. Handles platform differences:
    # - POSIX: VAR=value command
    # - Windows: set VAR=value && command
    #
    # @param command [String] Command to execute
    # @param config_home [String] Path for XDG_CONFIG_HOME
    # @return [String] Platform-appropriate command string
    def self.xdg_command(command : String, config_home : String) : String
      escaped_config_home = escape(config_home)
      {% if flag?(:win32) %}
        # Windows: Use 'set VAR=VALUE && command'
        "set XDG_CONFIG_HOME=#{escaped_config_home} && #{command}"
      {% else %}
        # POSIX: Use 'VAR=VALUE command'
        "XDG_CONFIG_HOME=#{escaped_config_home} #{command}"
      {% end %}
    end
  end
end
