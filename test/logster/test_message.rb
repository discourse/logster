require_relative '../test_helper'
require 'logster/message'

class TestMessage < MiniTest::Test

  def test_merge_similar
    msg1 = Logster::Message.new(0, '', 'test', 10)
    msg1.populate_from_env(a: "1", b: "2")

    msg2 = Logster::Message.new(0, '', 'test', 20)
    msg2.populate_from_env(a: "2", c: "3")

    assert_equal(msg2.grouping_key, msg1.grouping_key)

    msg1.merge_similar_message(msg2)

    msg1 = Logster::Message.from_json(msg1.to_json)

    assert_equal(20, msg1.timestamp)
    assert_equal(10, msg1.first_timestamp)
  end

  def test_adds_application_version
    Logster.config.application_version = "abc"
    msg = Logster::Message.new(0, '', 'test', 10)
    msg.populate_from_env({})

    assert_equal("abc", msg.env["application_version"])

  ensure
    Logster.config.application_version = nil
  end

end
