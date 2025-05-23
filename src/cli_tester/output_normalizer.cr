require "file_utils"
require "colorize" # For ANSI stripping

module CliTester
  # Normalizes CLI output for reliable comparisons in tests.
  #
  # Performs these transformations:
  # 1. Strips ANSI color codes (e.g., \e[32m → removed)
  # 2. Replaces temp paths with {base} and home dir with {home}
  # 3. Removes non-printable chars (keeps \t and \n)
  #
  # Example:
  #   Input: "\e[32m/tmp/cli-test-abc123/file.txt\e[0m"
  #   Output: "{base}/file.txt"
  module OutputNormalizer
    # Strips ANSI escape codes (like colors) from a string.
    #
    # Example: `strip_ansi_codes("\e[31mRed\e[0m") # => "Red"`
    def self.strip_ansi_codes(string : String) : String
      # Replace with ANSI code regex removal
      string.gsub(/\e\[\d+(;\d+)*m/, "")
    end

    # Normalizes paths within a string.
    # Replaces the provided `base_path` with `{base}` and the user's home
    # directory with `{home}`.
    #
    # Example: `normalize_paths("Output in /tmp/cli_tester-xyz/out", "/tmp/cli_tester-xyz") # => "Output in {base}/out"`
    def self.normalize_paths(string : String, base_path : String) : String
      # Ensure base_path doesn't have a trailing slash for consistent replacement
      normalized_base = base_path.chomp('/')
      # Escape base_path for regex safety, especially on Windows
      escaped_base_path = Regex.escape(normalized_base)

      # Replace base path first
      str = string.gsub(Regex.new(escaped_base_path), "{base}")

      # Replace home directory if possible
      begin
        # Prefer ENV["HOME"], fallback to Dir.home, handle potential errors
        home_dir = ENV["HOME"]? || Path.home.to_s
        unless home_dir.empty?
          # Escape home_dir for regex safety
          escaped_home_dir = Regex.escape(home_dir)
          str = str.gsub(Regex.new(escaped_home_dir), "{home}")
        end
      rescue ex : ArgumentError # Dir.home might fail if HOME env var isn't set
      # Log warning or ignore? For now, ignore.
      end

      str
    end

    # Removes non-printable characters except for newline and tab.
    # Keeps standard printable ASCII characters and common whitespace.
    #
    # Example: `clean_special_chars("Hello\bWorld") # => "HelloWorld"`
    def self.clean_special_chars(string : String) : String
      # This regex keeps printable ASCII, newline, and tab
      # `[[:print:]]` includes letters, digits, punctuation, space.
      string.gsub(/[^[:print:]\n\t]/, "")
    end

    # Applies a standard set of normalizations to a string.
    # Strips ANSI, normalizes paths, and cleans special characters.
    #
    # @param string [String] The raw output string
    # @param base_path [String] The base temporary directory path for normalization
    # @return [String] The normalized string
    def self.normalize(string : String, base_path : String) : String
      str = strip_ansi_codes(string)
      str = normalize_paths(str, base_path)
      str = clean_special_chars(str)
      # TODO: Add line ending normalization (CRLF -> LF)?
      # TODO: Add empty line filtering?
      str
    end
  end
end
