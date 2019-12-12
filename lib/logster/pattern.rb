# frozen_string_literal: true

module Logster
  class Pattern
    @child_classes = []

    class PatternError < StandardError; end

    def self.inherited(subclass)
      @child_classes << subclass
      super
    end

    def self.child_classes
      @child_classes
    end

    def self.set_name
      raise "Please override the `set_name` method and specify and a name for this set"
    end

    def self.parse_pattern(string)
      return string if Regexp === string
      return unless String === string
      if string[0] == "/"
        return unless string =~ /\/(.+)\/(.*)/
        string = $1
        flag = Regexp::IGNORECASE if $2 && $2.include?("i")
      end
      Regexp.new(string, flag)
    rescue RegexpError
      nil
    end

    def self.find_all(raw: false, store: Logster.store)
      patterns = store.get_patterns(set_name) || []
      unless raw
        patterns.map! do |p|
          parse_pattern(p)
        end
      end
      patterns.compact!
      patterns
    end

    def self.find(pattern, store: Logster.store)
      pattern = parse_pattern(pattern).inspect
      return nil unless pattern
      pattern = find_all(raw: true, store: store).find { |p| p == pattern }
      return nil unless pattern
      new(pattern)
    end

    def self.valid?(pattern)
      return false unless Regexp === pattern
      pattern_size = pattern.inspect.size
      pattern_size > 3 && pattern_size < 500
    end

    def initialize(pattern, store: Logster.store)
      self.pattern = pattern
      @store = store
    end

    def valid?
      self.class.valid?(pattern)
    end

    def to_s
      pattern.inspect
    end

    def save(args = {})
      ensure_valid!
      @store.insert_pattern(set_name, self.to_s)
    end

    def modify(new_pattern)
      new_pattern = self.class.parse_pattern(new_pattern)
      raise PatternError.new unless self.class.valid?(new_pattern)
      destroy
      self.pattern = new_pattern
      save
    end

    def destroy
      @store.remove_pattern(set_name, self.to_s)
    end

    def pattern
      @pattern
    end

    private

    def pattern=(new_pattern)
      @pattern = self.class.parse_pattern(new_pattern)
    end

    def set_name
      self.class.set_name
    end

    def ensure_valid!
      raise PatternError.new("Invalid pattern") unless valid?
    end
  end
end
