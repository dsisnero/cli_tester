require "file_utils"
require "process"
require "log" # Added for InteractiveProcess logging

require "./cli_tester/*"

# CliTester provides utilities for end-to-end testing of CLI applications.
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
