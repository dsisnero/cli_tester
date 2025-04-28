require "file_utils"
require "colorize" # For diff output

module CliTester
  # Provides utilities for snapshot testing CLI output.
  # Compares actual output against a stored snapshot file and provides
  # helpful diffs on mismatch.
  module Snapshot
    # Asserts that the `actual` string matches the content of the `snapshot_file`.
    # If the snapshot file doesn't exist, it's created with the `actual` content.
    # If the content mismatches, it raises an assertion error showing a diff.
    #
    # TODO: Implement snapshot update mechanism (e.g., via environment variable).
    #
    # @param actual [String] The actual output string to compare.
    # @param snapshot_file [String] The relative path (within the project) to the snapshot file.
    # @param message [String?] Optional custom message for assertion failure.
    # @raise [Exception] If the actual content does not match the snapshot content.
    def self.assert_match_snapshot(actual : String, snapshot_file : String, message : String? = nil)
      snapshot_path = File.expand_path(snapshot_file) # Ensure absolute path
      snapshot_dir = File.dirname(snapshot_path)

      # Create snapshot directory if it doesn't exist
      FileUtils.mkdir_p(snapshot_dir) unless Dir.exists?(snapshot_dir)

      if File.exists?(snapshot_path)
        expected = File.read(snapshot_path)

        unless actual == expected
          # TODO: Implement a proper diff algorithm/library
          # Basic diff for now:
          diff_message = "Snapshot mismatch for '#{snapshot_file}'\n"
          diff_message += "--- Expected\n".colorize(:red)
          diff_message += "#{expected}\n".colorize(:red)
          diff_message += "+++ Actual\n".colorize(:green)
          diff_message += "#{actual}\n".colorize(:green)

          error_message = message || diff_message
          raise Exception.new(error_message) # Or specific assertion error type
        end
      else
        # Snapshot file doesn't exist, create it
        File.write(snapshot_path, actual)
        puts "Snapshot created: #{snapshot_file}".colorize(:yellow) # Inform user
      end
    end
  end
end
