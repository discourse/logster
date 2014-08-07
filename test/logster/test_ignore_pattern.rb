require_relative '../test_helper'
require 'logster/ignore_pattern'

class TestIgnorePattern < Minitest::Test

  def test_string_message_pattern
    msg = Logster::Message.new(Logger::WARN, "test", "my error")
    msg_frog = Logster::Message.new(Logger::WARN, "test", "a frog")
    msg_nil = Logster::Message.new(Logger::WARN, "test", nil)

    pattern = Logster::IgnorePattern.new("ERROR")

    assert pattern.matches? msg
    assert !pattern.matches?(msg_frog)
    assert !pattern.matches?(msg_nil)
  end

  def test_env_pattern
    msg = Logster::Message.new(Logger::WARN, "test", "my error")
    msg.env = {"frogs" => "are big"}

    pattern = Logster::IgnorePattern.new(nil, {frogs: "big"})

    assert pattern.matches? msg

    msg.env = {legs: nil}
    assert !(pattern.matches? msg)

    msg.env = {legs: 3}
    assert !(pattern.matches? msg)

    msg.env = {frogs: "small"}
    assert !pattern.matches?(msg)

    pattern = Logster::IgnorePattern.new(nil, "small")
    assert pattern.matches? msg

    msg.env = {frogs: "big"}
    assert !(pattern.matches? msg)
  end
end
