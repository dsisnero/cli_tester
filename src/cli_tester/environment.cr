require "file_utils"
require "./mock_adapter"    # Require mock adapter for the new method
require "random/secure" # For temp dir naming in initialize
require "log"           # For logging
require "./shard_binary"  # Require the new ShardBinary helper
require "./shell"         # Require Shell for escape helper

module CliTester
  # Manages an isolated testing environment with temporary directory.
  # Provides file system operations, XDG directory management,
  # environment variable isolation, and process execution capabilities.
  class Environment
    # The absolute path to the temporary directory for this environment.
    getter path : String
    # Internal environment variables, including XDG paths
    getter env : Hash(String, String)
    # Stores original ENV values temporarily modified by `with_temp_env`
    @original_env = Hash(String, String?).new
    private getter interactive_processes = [] of InteractiveProcess

    # Creates a new temporary directory for the test environment.
    # Initializes internal environment variables, including XDG paths.
    def initialize
      @path = File.join(Dir.tempdir, "cli_tester-#{Random::Secure.hex(8)}")
      Dir.mkdir(@path)
      @env = Hash(String, String).new
      setup_xdg_environment
    end

    # Sets up standard XDG base directories (CONFIG_HOME, CACHE_HOME, etc)
    # within the test environment. These are automatically created and
    # destroyed with the environment. Accessed via @env hash.
    private def setup_xdg_environment
      xdg_base = File.join(@path, "xdg")
      make_dir(xdg_base) # Ensure the base XDG directory exists

      xdg_paths = {
        "XDG_CONFIG_HOME" => File.join(xdg_base, "config"),
        "XDG_CACHE_HOME"  => File.join(xdg_base, "cache"),
        "XDG_DATA_HOME"   => File.join(xdg_base, "data"),
        "XDG_STATE_HOME"  => File.join(xdg_base, "state"),
      }

      # Create each XDG directory
      xdg_paths.each_value do |path|
        # Use FileUtils.mkdir_p directly as make_dir resolves relative paths
        FileUtils.mkdir_p(path)
      end

      # Merge these paths into the environment's internal env hash
      @env.merge!(xdg_paths)
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

    # Creates a configuration file within the isolated XDG_CONFIG_HOME
    # directory structure. Files are automatically cleaned up with the
    # test environment.
    #
    # @param app_name [String] The application's config directory name
    # @param filename [String] Config file to create
    # @param content [String | Bytes] File contents
    def create_xdg_config(app_name : String, filename : String, content : String | Bytes)
      # Ensure XDG_CONFIG_HOME exists in our internal env
      config_home = @env["XDG_CONFIG_HOME"]? || raise "XDG_CONFIG_HOME not set up in environment"
      app_config_dir = File.join(config_home, app_name)
      FileUtils.mkdir_p(app_config_dir) # Ensure the app-specific config dir exists

      # Write the file using the absolute path
      File.write(File.join(app_config_dir, filename), content)
    end

    # Temporarily modifies environment variables for the duration of
    # the block. Restores original values automatically.
    #
    # @param env_vars [Hash(String, String?)] Variables to set (nil unsets)
    # @yield Block where temporary vars are active
    def with_temp_env(env_vars : Hash(String, String?), &)
      env_vars.each do |k, v|
        @original_env[k] = ENV[k]? # Store original value (or nil if not set)
        if v.nil?
          ENV.delete(k) # Unset the variable if value is nil
        else
          ENV[k] = v # Set the variable
        end
      end

      yield # Execute the block with the temporary environment


    ensure
      # Restore original environment variables
      @original_env.each do |k, original_value|
        if original_value.nil?
          ENV.delete(k) # If it was originally unset, unset it again
        else
          ENV[k] = original_value # Otherwise, restore the original value
        end
      end
      @original_env.clear # Clear the temporary storage
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
        # Merge internal env (@env) with any explicitly passed env vars
        env: @env.merge(env || {} of String => String),
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

    # Applies mocks defined by a `MockAdapter` within a block.
    # Ensures mocks are active only during the block's execution.
    #
    # @param adapter [MockAdapter] The mock adapter instance to apply.
    # @yield The block of code to execute with mocks enabled.
    #
    # Example:
    # ```
    # env.with_mocks(MyApiMock.new) do
    #   # Run commands that depend on the mocked behavior
    #   result = env.execute("my-cli make-api-call")
    #   # Assert based on mocked response
    # end
    # ```
    def with_mocks(adapter : MockAdapter, &)
      adapter.apply_mocks
      begin
        yield
      ensure
        # Optional: Call teardown if the adapter supports it
        # adapter.teardown_mocks if adapter.responds_to?(:teardown_mocks)
      end
    end

    # Compiles a target binary from the project being tested (identified by shard.yml)
    # into this test environment's temporary directory.
    # Delegates the compilation logic to `CliTester::ShardBinary`.
    #
    # @param name [String?] The specific target name from shard.yml to build.
    #                       If nil, uses the default logic in `ShardBinary.compile`.
    # @param build_args [Array(String)] Additional arguments for `crystal build`.
    # @return [String] The absolute path to the compiled binary within the environment.
    #
    # Example:
    # ```
    # CliTester.test do |env|
    #   # Compile the default binary for the project under test
    #   binary = env.shard_binary
    #   result = env.execute(binary + " --version")
    #
    #   # Compile a specific target with release flag
    #   release_binary = env.shard_binary("my_release_target", ["--release"])
    #   env.execute(release_binary + " --help")
    # end
    # ```
    def shard_binary(name : String? = nil, build_args : Array(String) = [] of String) : String
      # Instantiate ShardBinary helper, passing self (the environment)
      # It uses the class-level configured root_dir/shard_file and
      # this environment's path for the build output.
      ShardBinary.new(self).compile(name, build_args)
    end

    # Helper to escape a string for safe use as a command-line argument
    # on the current platform. Delegates to `CliTester::Shell.escape`.
    # Useful when executing binaries whose paths might contain spaces.
    #
    # Example: `env.execute(env.shell_escape(binary_path) + " --arg")`
    def shell_escape(argument : String) : String
      CliTester::Shell.escape(argument)
    end
  end
end
