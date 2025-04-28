require "file_utils"
require "process"
require "log" # Added for InteractiveProcess logging

require "./cli_tester/*"

# CliTester provides utilities for end-to-end testing of CLI applications.
# It allows executing commands, interacting with prompts, and managing
# a temporary testing environment, similar to the concepts in
# https://github.com/gmrchk/cli-testing-library
#
# ## Basic Usage
#
# ```
# require "cli_tester"
#
# CliTester.test do |env|
#   # Prepare files in the temporary environment
#   env.write_file("input.txt", "Hello World")
#
#   # Execute the CLI command
#   result = env.execute("your_cli_command --input input.txt")
#
#   # Assertions on the result
#   result.success?.should be_true
#   result.stdout.should contain("Expected output")
#   env.exists?("output.log").should be_true
# end
# ```
module CliTester
  # Sets up a temporary environment for a CLI test, yields it to the block,
  # and ensures cleanup afterwards.
  #
  # ```
  # CliTester.test do |env|
  #   # Use env methods here
  #   result = env.execute("echo 'hello'")
  #   result.stdout.should eq("hello\n")
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
