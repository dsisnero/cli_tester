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
# It automatically detects the `shard.yml` of the project being tested
# upon being required, making project metadata available via class properties.
#
# Key components:
# - `CliTester.test` - Main entry point that creates a temporary environment
# - `Environment` - Manages temp directory and provides file/process operations
# - `InteractiveProcess` - Controls long-running processes with I/O interaction
# - `ExecutionResult` - Contains results of executed commands
#
# Example testing workflow:
# 1. Create temp environment with `CliTester.test`
# 2. Set up test files using Environment methods
# 3. Execute commands and validate results
# 4. Cleanup is automatic
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
