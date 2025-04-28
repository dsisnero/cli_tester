module CliTester
  # Holds the results of executing a command via `Environment#execute`.
  struct ExecutionResult
    # The standard output captured from the command.
    getter stdout : String

    # The standard error captured from the command.
    getter stderr : String

    # The exit status of the executed process.
    getter status : Process::Status

    def initialize(@stdout, @stderr, @status)
    end

    # Returns the integer exit code of the process.
    def exit_code : Int32
      @status.exit_code
    end

    # Returns `true` if the command exited successfully (exit code 0).
    def success? : Bool
      @status.success?
    end
  end
end
