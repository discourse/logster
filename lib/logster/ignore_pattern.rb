module Logster
  class IgnorePattern

    def initialize(message_pattern=nil, env_patterns=nil)
      @msg_match = message_pattern
      @env_match = env_patterns
    end

    def self.from_message_and_request_uri(msg, request)
      IgnorePattern.new(msg, {REQUEST_URI: request})
    end

    def matches?(message)
      if @msg_match
        return false unless compare(message.message, @msg_match)
      end

      if @env_match
        return false unless compare(message.env, @env_match)
      end

      true
    end

    def to_s
      "<#Logster::IgnorePattern, msg_match: #{@msg_match.inspect}, env_match: #{@env_match.inspect}>"
    end

    private

    def compare(message, pattern)
      case pattern
        when Regexp
          message =~ pattern
        when String
          message.downcase =~ Regexp.new(pattern.downcase, Regexp::IGNORECASE)
        when Hash
          compare_hash(message, pattern)
        when NilClass
          true
        else
          true
      end
    end

    def compare_hash(message_hash, pattern_hash)
      return false unless message_hash
      pattern_hash.each do |key, value|
        return false unless compare(get_indifferent(message_hash, key), value)
      end
      true
    end

    def get_indifferent(hash, key)
      return hash[key] if hash[key]
      return hash[key.to_s] if hash[key.to_s]
      return hash[key.to_sym] if hash[key.to_sym]
      nil
    end
  end
end
