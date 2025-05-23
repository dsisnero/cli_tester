require "process"
require "log"

module CliTester
  # Controls long-running interactive processes with I/O management.
  # Enables testing of CLI tools that prompt for input.
  #
  # Example:
  #   process = env.spawn("my-cli --interactive")
  #   process.wait_for_text("Username:")
  #   process.write_text("testuser")
  #   process.wait_for_finish
  class InteractiveProcess
    getter process : Process
    getter stdin : IO
    getter stdout : IO
    getter stderr : IO

    # Internal buffers to store output read by background fibers
    private getter stdout_buffer = IO::Memory.new
    private getter stderr_buffer = IO::Memory.new
    private getter? running = true
    private getter? killed = false

    # Channel to signal when process has exited
    private getter exit_channel = Channel(Process::Status).new(1)

    # Logger for debugging interaction issues
    Log = ::Log.for(self)

    # Initializes the interactive process, starting background readers.
    # Should generally be created via `Environment#spawn`.
    def initialize(@process)
      @stdin = @process.input
      @stdout = @process.output
      @stderr = @process.error

      # Spawn fibers to continuously read stdout/stderr to prevent blocking
      spawn read_output(@stdout, @stdout_buffer, "stdout")
      spawn read_output(@stderr, @stderr_buffer, "stderr")
      spawn wait_for_exit
    end

    # Background fiber task to wait for process exit and signal channel.
    private def wait_for_exit
      status = @process.wait
      @running = false
      @exit_channel.send(status)
      Log.debug { "Process exited with status: #{status.exit_code}" }
    rescue ex : IO::Error # Changed from Process::Error
      # This might happen if the process was killed externally or couldn't start
      @running = false
      Log.error(exception: ex) { "Error waiting for process exit" }
      # Ensure channel receives *something* if wait fails unexpectedly
      @exit_channel.send(Process::Status.new(-1)) unless @exit_channel.closed?
    ensure
      # Close pipes if they are still open
      close_pipes
      # Ensure channel is closed if not already
      @exit_channel.close unless @exit_channel.closed?
    end

    # Background fiber task to read from a process pipe into a buffer.
    private def read_output(pipe : IO, buffer : IO::Memory, name : String)
      buffer_chunk = Bytes.new(1024)
      loop do
        bytes_read = pipe.read(buffer_chunk)
        if bytes_read == 0 # Pipe closed (usually means process exited)
          Log.debug { "#{name} pipe closed" }
          break
        end
        buffer.write(buffer_chunk.to_slice(0, bytes_read))
        Log.debug { "Read #{bytes_read} bytes from #{name}" }
      rescue ex : IO::Error # Pipe might be closed unexpectedly
        Log.warn(exception: ex) { "Error reading from #{name}" }
        break
      end
    rescue ex # Catch any other unexpected errors in the fiber
      Log.error(exception: ex) { "Unhandled error in read_output(#{name})" }
    end

    # Closes the process pipes safely.
    private def close_pipes
      {@stdin, @stdout, @stderr}.each do |pipe|
        pipe.close unless pipe.closed?
      rescue IO::Error
        # Ignore errors closing already closed pipes
      end
    end

    # Writes text to the process's standard input.
    # Appends a newline by default, simulating pressing Enter.
    def write_text(text : String, newline = true)
      check_running!
      Log.debug { "Writing text: #{text.inspect}" }
      @stdin.print text
      @stdin.print "\n" if newline
      @stdin.flush
    end

    # Simulates pressing a specific key. Currently only supports "Enter".
    # TODO: Expand to support other keys (arrow keys, etc.) using escape codes.
    def press_key(key_name : String)
      check_running!
      case key_name.downcase
      when "enter"
        Log.debug { "Pressing Enter (writing newline)" }
        @stdin.print "\n"
        @stdin.flush
      else
        raise ArgumentError.new("Unsupported key name: #{key_name}")
      end
    end

    # Waits until the specified text appears in stdout or stderr.
    # Raises Timeout::Error if the text doesn't appear within the timeout.
    #
    # Waits for specific text to appear in process output.
    #
    # @param text_to_find [String] Text pattern to wait for
    # @param stream [Symbol] :stdout or :stderr to monitor
    # @param timeout [Time::Span] Maximum wait duration
    # @raise [Timeout::Error] If text not found before timeout
    #
    # Example:
    # ```
    # process.wait_for_text("Password:", timeout: 10.seconds)
    # ```
    def wait_for_text(text_to_find : String, stream : Symbol = :stdout, timeout : Time::Span = 5.seconds)
      check_running!
      buffer = if stream == :stdout
                 @stdout_buffer
               else
                 @stderr_buffer
               end
      start_time = Time.monotonic
      current_pos = 0 # Position in the buffer to start searching from

      Log.debug { "Waiting for text in #{stream}: #{text_to_find.inspect}" }

      loop do
        # Check remaining time
        elapsed = Time.monotonic - start_time
        if elapsed >= timeout
          raise Timeout::Error.new("Timeout waiting for text: #{text_to_find.inspect} in #{stream}")
        end

        # Read current buffer content non-destructively
        buffer.rewind
        current_content = buffer.gets_to_end
        buffer.seek(0, IO::Seek::End) # Reset position for writers

        # Search only the new part of the buffer
        if current_pos < current_content.bytesize
          search_area = current_content.byte_slice(current_pos)
          if search_area.includes?(text_to_find)
            Log.debug { "Found text: #{text_to_find.inspect}" }
            return # Text found
          end
          current_pos = current_content.bytesize
        end

        # If process exited while waiting, check one last time then raise
        unless running?
          buffer.rewind

          # Read final content after process exit
          final_content = buffer.gets_to_end
          if final_content.byte_slice(current_pos).includes?(text_to_find)
            Log.debug { "Found text after process exit: #{text_to_find.inspect}" }
            return
          else
            raise Process::Error.new("Process exited before text was found: #{text_to_find.inspect}")
          end
        end

        # Sleep briefly before checking again
        sleep 0.05
      end
    end

    #   # Waits for the process to finish execution.
    #   # Raises Timeout::Error if the process doesn't finish within the timeout.
    def wait_for_finish(timeout : Time::Span = 5.seconds) : Process::Status
      return @exit_channel.receive? || Process::Status.new(-1, Signal::KILL) unless running? # Already finished

      Log.debug { "Waiting for process to finish (timeout: #{timeout})" }
      status = Timeout.timeout(timeout) do
        @exit_channel.receive
      end
      Log.debug { "Process finished with status: #{status.exit_code}" }
      status
    rescue ex : Timeout::Error
      Log.warn { "Timeout waiting for process finish. Killing process." }
      kill # Attempt to kill if timed out
      raise ex
    end

    #   # Returns all standard output captured so far.
    def get_stdout : String
      @stdout_buffer.rewind
      content = @stdout_buffer.gets_to_end
      @stdout_buffer.seek(0, IO::Seek::End) # Reset position
      content
    end

    #   # Returns all standard error captured so far.
    def get_stderr : String
      @stderr_buffer.rewind
      content = @stderr_buffer.gets_to_end
      @stderr_buffer.seek(0, IO::Seek::End) # Reset position
      content
    end

    #   # Returns the exit code if the process has finished, otherwise nil.
    def get_exit_code : Int32?
      if status = @exit_channel.receive?
        status.exit_code
      end
    end

    #   # Returns the exit status if the process has finished, otherwise nil.
    def get_status : Process::Status?
      @exit_channel.receive?
    end

    # Forcefully terminates the process and cleans up resources.
    # Sends SIGKILL and closes all I/O pipes.
    #
    # Example:
    # ```
    # process.kill if timeout
    # ```
    def kill
      if running? && !killed?
        Log.warn { "Killing process (PID: #{@process.pid})" }
        @killed = true
        @process.signal(Signal::KILL)
        @running = false # Assume killed means not running
        close_pipes
        # Ensure exit channel gets a status even if killed
        @exit_channel.send(Process::Status.new(-1)) unless @exit_channel.closed?
      end
    rescue ex : IO::Error
      Log.error(exception: ex) { "Error killing process" }
      # Might already be dead
      @running = false
    end

    private def check_running!
      raise IO::Error.new("Process is not running.") unless running?
    end
  end
end
