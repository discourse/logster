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
      return false unless message && pattern

      case pattern
        when Regexp
          message.to_s =~ pattern
        when String
          message.to_s.downcase =~ Regexp.new(pattern.downcase, Regexp::IGNORECASE)
        when Hash
          if Hash === message
            compare_hash(message, pattern)
          else
            false
          end
        else
          false
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
      # no key.to_sym please, memory leak in Ruby < 2.2
      nil
    end
  end
end
