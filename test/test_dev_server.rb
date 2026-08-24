# frozen_string_literal: true

require_relative "test_helper"
require_relative "../dev_server_process"

class TestDevServerProcess < Minitest::Test
  def test_identifies_the_first_process_that_exits
    processes = [["backend", 101], ["frontend", 202]]

    stopped = DevServerProcess.wait_for_process_exit(processes, wait: -> { 202 })

    assert_equal(["frontend", 202], stopped)
  end
end
