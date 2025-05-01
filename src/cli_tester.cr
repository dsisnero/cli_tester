require "file_utils"
require "process"
require "log"
require "colorize" # Added for snapshot output

require "./cli_tester/environment"
require "./cli_tester/execution_result"
require "./cli_tester/interactive_process"
require "./cli_tester/output_normalizer"
require "./cli_tester/mock_adapter"
require "./cli_tester/snapshot"
require "./cli_tester/shell"
require "./cli_tester/shard_binary" # Added

# CliTester provides utilities for end-to-end testing of CLI applications.
#
# Key features:
# - Automatic shard.yml detection and validation
# - Isolated test environments with XDG compliance
# - Interactive process testing
# - Snapshot testing with output normalization
# - YAML configuration validation (shard.yml parsing)
#
# The module automatically detects and validates the project's shard.yml
# configuration on load, making project metadata available via:
# - CliTester.root_dir
# - CliTester.shard_file
# - CliTester::Shard.parse (for manual validation)
#
# Example test workflow:
# 1. Create temp environment with CliTester.test
# 2. Validate project configuration via CliTester::Shard
# 3. Execute commands and validate behavior
# 4. Automatic cleanup
module CliTester
  # Sets up a temporary environment for a CLI test, yields it to the block,
  # and ensures cleanup afterwards.
  #
  # @yield [Environment] Provides access to the test environment
  #
  # Example:
  # ```
  # CliTester.test do |env|
  #   env.write_file("test.txt", "content")
  #   result = env.execute("cat test.txt")
  #   result.stdout.should eq("content")
  # end
  # ```
  # Automatically configure ShardBinary when the module is loaded.
  # This finds the project's root directory and shard.yml file.
  ShardBinary.configure

  # The root directory of the project being tested (where shard.yml was found).
  # Set automatically by `ShardBinary.configure`.
  class_property root_dir : String = ShardBinary.root_dir

  # The path to the shard.yml file of the project being tested.
  # Set automatically by `ShardBinary.configure`.
  class_property shard_file : String = ShardBinary.shard_file

  # Sets up a temporary environment for a CLI test, yields it to the block,
  # and ensures cleanup afterwards.
  #
  # @yield [Environment] Provides access to the test environment
  #
  # Example:
  # ```
  # CliTester.test do |env|
  #   env.write_file("test.txt", "content")
  #   result = env.execute("cat test.txt")
  #   result.stdout.should eq("content")
  # end
  # ```
  def self.test(& : Environment -> _)
    env = Environment.new
    begin
      env.chdir do
        yield env
      end
    ensure
      env.cleanup
    end
  end
end
