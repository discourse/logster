# frozen_string_literal: true

require_relative '../test_helper'
require 'logster/group'
require 'logster/message'

class TestGroup < MiniTest::Test
  def test_changed_is_true_for_new_instances
    assert Logster::Group.new("/somekey/").changed?
  end

  def test_from_json_works_correctly
    time = (Time.new.to_f * 1000).to_i - 5000
    json = JSON.generate(
      key: '/somekey/',
      messages_keys: [111, 222, 333].map(&:to_s),
      timestamp: time
    )
    group = Logster::Group.from_json(json)
    refute group.changed?
    assert_equal 3, group.count
    assert_equal time, group.timestamp
  end

  def test_doesnt_add_duplicate_messages
    group = get_group
    msg1 = get_message
    assert_equal 0, group.count
    group.add_message(msg1)
    assert_equal 1, group.count
    assert_equal msg1.timestamp, group.timestamp
    group.add_message(msg1)
    assert_equal 1, group.count

    msg2 = get_message
    msg2.timestamp -= 10000
    group.add_message(msg2)
    assert_equal 2, group.count
    assert_equal msg1.timestamp, group.timestamp
  end

  def test_adding_multiple_messages_works_correctly
    group = get_group
    messages = [
      get_message(10),
      get_message(5),
      get_message(74),
      get_message(26)
    ]
    messages << messages[0]
    group.messages = messages
    assert_equal 4, group.count
    assert_equal 74, group.timestamp
    expected = messages.uniq(&:key).sort_by(&:timestamp).map(&:key)
    assert_equal expected, group.messages_keys
  end

  def test_doesnt_exceed_max_size
    Logster::Group.max_size = 5
    group = get_group
    messages = [
      get_message(10),
      get_message(5),
      get_message(74),
      get_message(26),
      get_message(44),
      get_message(390)
    ]
    messages.each { |m| group.add_message(m) }
    assert_equal 5, group.count
    assert_equal 390, group.timestamp
    refute_includes group.messages_keys, messages.find { |m| m.timestamp == 10 }.key

    group = get_group
    group.messages = messages
    assert_equal 5, group.count
    assert_equal 390, group.timestamp
    refute_includes group.messages.map(&:timestamp), 5
  ensure
    Logster::Group.max_size = nil
  end

  private

  def get_group
    Logster::Group.new("/groupkey/")
  end

  def get_message(timestamp = nil)
    Logster::Message.new(0, '', 'testmessage', timestamp)
  end
end
