require "file_utils"

module CliTester
  # Manages an isolated testing environment with temporary directory.
  # Provides file system operations and process execution capabilities.
  class Environment
    # The absolute path to the temporary directory for this environment.
    getter path : String
    private getter interactive_processes = [] of InteractiveProcess

    # Creates a new temporary directory for the test environment.
    def initialize
      @path = File.join(Dir.tempdir, "cli_tester-#{Random::Secure.hex(8)}")
      Dir.mkdir(@path)
    end

    # Removes the temporary directory and all its contents.
    # Also ensures any spawned interactive processes are killed.
    # This is typically called automatically by `CliTester.test`.
    def cleanup
      # Kill any running interactive processes first
      @interactive_processes.each &.kill
      @interactive_processes.clear

      # Then remove the temp directory
      FileUtils.rm_rf(@path) if Dir.exists?(@path)
    end

    # Returns the absolute path for a given relative path within the environment.
    private def resolve(relative_path)
      File.expand_path(relative_path, @path)
    end

    # Changes the current working directory to the environment's temporary
    # directory for the duration of the block.
    def chdir(&)
      Dir.cd(@path) do
        yield
      end
    end

    # Creates a directory within the environment.
    # Creates parent directories if they don't exist.
    #
    # Example: `env.make_dir("some/nested/dir")`
    def make_dir(path : String)
      FileUtils.mkdir_p(resolve(path))
    end

    # Writes content to a file within the environment.
    # Creates parent directories if they don't exist.
    # Overwrites the file if it already exists.
    #
    # Example: `env.write_file("my_file.txt", "File content")`
    def write_file(path : String, content : String | Bytes)
      full_path = resolve(path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
    end

    # Reads the content of a file within the environment.
    # Raises an exception if the file does not exist.
    #
    # Example: `content = env.read_file("my_file.txt")`
    def read_file(path : String) : String
      File.read(resolve(path))
    end

    # Reads the content of a file within the environment as bytes.
    # Raises an exception if the file does not exist.
    #
    # Example: `bytes = env.read_file_bytes("my_binary_file")`
    def read_file_bytes(path : String) : Bytes
      File.open(resolve(path), "rb") do |file|
        file.getb_to_end
      end
    end

    # Removes a file within the environment.
    # Does nothing if the file does not exist.
    #
    # Example: `env.remove_file("my_file.txt")`
    def remove_file(path : String)
      FileUtils.rm_rf(resolve(path))
    end

    # Removes a directory and its contents recursively within the environment.
    # Does nothing if the directory does not exist.
    #
    # Example: `env.remove_dir("some/dir")`
    def remove_dir(path : String)
      FileUtils.rm_rf(resolve(path))
    end

    # Checks if a file or directory exists within the environment.
    #
    # Example: `if env.exists?("my_file.txt") ...`
    def exists?(path : String) : Bool
      File.exists?(resolve(path))
    end

    # Lists the names of files and directories directly within the specified
    # directory path inside the environment. Does not include "." or "..".
    # Raises an exception if the directory does not exist.
    #
    # Example: `entries = env.ls(".")`
    def ls(path : String) : Array(String)
      Dir.entries(resolve(path)).reject { |entry| entry == "." || entry == ".." }
    end

    # Executes a command synchronously within the environment's directory.
    # Executes a command and returns captured results.
    #
    # @param command [String] Shell command to execute
    # @param input [String | Bytes] Input for stdin (optional)
    # @param env [Hash(String, String)] Environment variables (optional)
    # @return [ExecutionResult] Captured output and exit status
    #
    # Example:
    # ```
    # result = env.execute("echo 'hello'", env: {"DEBUG" => "1"})
    # result.stdout.should contain("hello")
    # ```
    def execute(command : String, input : String | Bytes | Nil = nil, env : Hash(String, String) | Nil = nil) : ExecutionResult
      stdout = IO::Memory.new
      stderr = IO::Memory.new
      stdin = input ? IO::Memory.new(input) : nil

      # Use Process.run which handles shell expansion if needed
      status = Process.run(
        command,
        shell: true,                                # Allows shell features like pipes and redirection within the command string
        input: stdin || Process::Redirect::Inherit, # Use provided input or inherit
        output: stdout,
        error: stderr,
        env: env,
        chdir: @path # Ensure command runs in the temp dir
      )

      ExecutionResult.new(stdout.to_s, stderr.to_s, status)
    end

    # Spawns a command interactively within the environment's directory.
    # Returns an `InteractiveProcess` object to interact with the running command.
    #
    # Example:
    # ```
    # process = env.spawn("my_interactive_cli")
    # process.wait_for_text("Enter your name:")
    # process.write_text("Tester")
    # result = process.wait_for_finish
    # ```
    #
    # Spawns an interactive process for step-by-step control.
    #
    # @param command [String] Command to start
    # @param env [Hash(String, String)] Environment variables (optional)
    # @return [InteractiveProcess] Controller for process interaction
    #
    # Example:
    # ```
    # process = env.spawn("my_cli --interactive")
    # process.wait_for_text("Username:")
    # process.write_text("test_user")
    # ```
    def spawn(command : String, env : Hash(String, String) | Nil = nil) : InteractiveProcess
      process = Process.new(
        command,
        shell: true,
        input: Process::Redirect::Pipe,
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Pipe,
        env: env,
        chdir: @path
      )

      interactive_process = InteractiveProcess.new(process)
      @interactive_processes << interactive_process
      interactive_process
    end
  end
end
