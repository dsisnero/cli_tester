module CliTester
  # Represents the results of executing a command via `Environment#execute`.
  # Captures standard output, standard error, and process status information.
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

    # Determines if the command executed successfully.
    # @return [Bool] True if exit code is zero, false otherwise
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
  end
end
