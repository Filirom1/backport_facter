class Facter::Core::Execution::Base

  def execute(command, options = {})

    on_fail = options.fetch(:on_fail, :raise)

    # Set LC_ALL and LANG to force i18n to C for the duration of this exec; this ensures that any code that parses the
    # output of the command can expect it to be in a consistent / predictable format / locale
    with_env 'LC_ALL' => 'C', 'LANG' => 'C' do

      expanded_command = expand_command(command)

      if expanded_command.nil?
        if on_fail == :raise
          raise Facter::Core::Execution::ExecutionFailure.new, "Could not execute '#{command}': command not found"
        else
          return on_fail
        end
      end

      out = ''

      begin
        if options[:timeout]
          out = run_with_timeout(expanded_command, options[:timeout], 1).chomp
        else
          out = %x{#{expanded_command}}.chomp
        end
      rescue => detail
        if on_fail == :raise
          raise Facter::Core::Execution::ExecutionFailure.new, "Failed while executing '#{expanded_command}': #{detail.message}"
        else
          return on_fail
        end
      end

      out
    end
  end

  # Forked from  https://gist.github.com/lpar/1032297
  # Runs a specified shell command in a separate thread.
  # If it exceeds the given timeout in seconds, kills it.
  # Returns any output produced by the command (stdout or stderr) as a String.
  # Uses Kernel.select to wait up to the tick length (in seconds) between 
  # checks on the command's status
  #
  # If you've got a cleaner way of doing this, I'd be interested to see it.
  # If you think you can do it with Ruby's Timeout module, think again.
  def run_with_timeout(command, timeout, tick)
    output = ''
    begin
      # Start task in another thread, which spawns a process
      stdin, stderr, stdout, thread = Open3.popen3(command)
      # Get the pid of the spawned process
      pid = thread[:pid]
      start = Time.now

      while (Time.now - start) < timeout and thread.alive?
        # Wait up to `tick` seconds for output/error data
        Kernel.select([stderr, stdout], nil, nil, tick)
        # Try to read the data
        begin
          output << stderr.read_nonblock(BUFFER_SIZE)
          output << stdout.read_nonblock(BUFFER_SIZE)
        rescue IO::WaitReadable
          # A read would block, so loop around for another select
        rescue EOFError
          # Command has completed, not really an error...
          break
        end
      end
      # Give Ruby time to clean up the other thread
      sleep 1

      if thread.alive?
        # We need to kill the process, because killing the thread leaves
        # the process alive but detached, annoyingly enough.
        Process.kill("TERM", pid)
      end
    ensure
      stdin.close if stdin
      stderr.close if stderr
      stdout.close if stdout
    end
    return output
  end
end
