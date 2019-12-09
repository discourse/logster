# frozen_string_literal: true

module Logster
  class Group
    MAX_SIZE = 100

    attr_reader :key, :messages_keys, :timestamp, :messages
    attr_accessor :changed

    def initialize(key, messages_keys = [], timestamp: nil)
      @key = key
      @messages_keys = messages_keys || []
      @timestamp = timestamp || 0
      @changed = true
    end

    def self.from_json(json)
      hash = JSON.parse(json)
      group = new(
        hash["key"],
        hash["messages_keys"],
        timestamp: hash["timestamp"]
      )
      group.changed = false
      group
    end

    def self.max_size
      (defined?(@max_size) && @max_size) || MAX_SIZE
    end

    def self.max_size=(num) # used in tests
      @max_size = num
    end

    def to_h
      {
        key: @key,
        messages_keys: @messages_keys,
        timestamp: @timestamp
      }
    end

    def to_h_web
      {
        regex: @key,
        count: self.count,
        timestamp: @timestamp,
        messages: @messages,
        severity: -1,
        group: true
      }
    end

    def to_json(opts = nil)
      JSON.fast_generate(self.to_h, opts)
    end

    def add_message(message)
      if !@messages_keys.include?(message.key)
        @messages_keys << message.key
        @changed = true
      end
      if @timestamp < message.timestamp
        @timestamp = message.timestamp
        @messages_keys << @messages_keys.slice!(@messages_keys.index(message.key))
        @changed = true
      end
      if self.count > max_size
        @messages_keys = @messages_keys[-max_size..-1]
        @changed = true
      end
    end

    def remove_message(message)
      index = @messages_keys.index(message.key)
      if index
        @messages_keys.slice!(index)
        @changed = true
      end
    end

    def messages=(messages)
      messages.compact!
      messages.uniq!(&:key)
      if messages.size > 0
        messages.sort_by!(&:timestamp)
        @messages = messages.size > max_size ? messages[-max_size..-1] : messages
        before = @messages_keys.sort
        @messages_keys = @messages.map(&:key)
        @timestamp = @messages.max_by(&:timestamp).timestamp
        @changed = before != @messages_keys.sort
      else
        @messages_keys = []
        @messages = []
        @timestamp = 0
        @changed = true
      end
      @messages
    end

    def changed?
      @changed
    end

    def count
      @messages_keys.size
    end

    private

    def max_size
      self.class.max_size
    end

    GroupWeb = Struct.new(*%i[regex count timestamp messages row_id]) do
      def to_json(opts = nil)
        JSON.fast_generate(self.to_h.merge(severity: -1, group: true), opts)
      end

      def key
        self.regex # alias for testing convenience
      end
    end
  end
end
