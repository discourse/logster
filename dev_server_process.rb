# frozen_string_literal: true

module DevServerProcess
  module_function

  def wait_for_process_exit(processes, wait: -> { Process.wait })
    stopped_pid = wait.call
    processes.find { |_, process_pid| process_pid == stopped_pid } || ["server", stopped_pid]
  end
end
