require "file_utils"

module CliTester
  # Represents the isolated temporary environment for a single test run.
  # Provides methods for file system manipulation and command execution
  # within this environment.
  class Environment
    # The absolute path to the temporary directory for this environment.
    getter path : String

    # Creates a new temporary directory for the test environment.
    def initialize
      @path = Dir.mktmpdir("cli_tester-")
    end

    # Removes the temporary directory and all its contents.
    # This is typically called automatically by `CliTester.test`.
    def cleanup
      FileUtils.rm_rf(@path) if Dir.exists?(@path)
    end

    # Returns the absolute path for a given relative path within the environment.
    private def resolve(relative_path)
      File.expand_path(relative_path, @path)
    end

    # Changes the current working directory to the environment's temporary
    # directory for the duration of the block.
    def chdir(&block)
      Dir.cd(@path) do
        yield
      end
    end

    # TODO: Add file system helper methods (writeFile, readFile, exists?, etc.)
    # TODO: Add command execution method (execute)
  end
end
