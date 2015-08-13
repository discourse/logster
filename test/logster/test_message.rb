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

end
