require "./output_normalizer"

module CliTester
  # Contains results from a command execution via `Environment#execute`.
  # Includes raw output/status and provides methods for normalized output.
  #
  # Provides:
  # - Captured standard output
  # - Captured standard error
  # - Process exit status
  # - Success checking
  struct ExecutionResult
    # The captured standard output from the executed command as a String.
    # Contains all text written to stdout during command execution.
    getter stdout : String

    # The captured standard error from the executed command as a String.
    # Contains all text written to stderr during command execution.
    getter stderr : String

    # The exit status information from the executed process.
    # Provides access to exit code and signal termination details.
    getter status : Process::Status

    # Creates a new ExecutionResult instance.
    # @param stdout [String] Captured standard output
    # @param stderr [String] Captured standard error
    # @param status [Process::Status] Process exit status information
    def initialize(@stdout, @stderr, @status)
    end

    # Returns the numeric exit code from the executed process.
    # @return [Int32] Exit code (0 typically indicates success)
    def exit_code : Int32
      @status.exit_code
    end

    # Returns true if process exited with status code 0
    #
    # Example:
    # ```
    # result.success?.should be_true
    # ```
    def success? : Bool
      @status.success?
    end

    # Returns a string representation of the execution results.
    # Includes exit code, success status, and output sizes.
    def to_s(io : IO) : Nil
      io << "ExecutionResult(\n"
      io << "  exit_code: #{exit_code},\n"
      io << "  success?: #{success?},\n"
      io << "  stdout_size: #{stdout.bytesize} bytes,\n"
      io << "  stderr_size: #{stderr.bytesize} bytes\n"
      io << ")"
    end

    # Returns the standard output normalized using `OutputNormalizer`.
    # Requires the `Environment` instance to know the base path for normalization.
    #
    # @param env [Environment] The environment in which the command was executed.
    # @return [String] Normalized standard output.
    def normalized_stdout(env : Environment) : String
      OutputNormalizer.normalize(@stdout, env.path)
    end

    # Returns the standard error normalized using `OutputNormalizer`.
    # Requires the `Environment` instance to know the base path for normalization.
    #
    # @param env [Environment] The environment in which the command was executed.
    # @return [String] Normalized standard error.
    def normalized_stderr(env : Environment) : String
      OutputNormalizer.normalize(@stderr, env.path)
    end
  end
end
