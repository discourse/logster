module Logster
  class Message
    attr_accessor :timestamp, :severity, :progname, :message, :key

    def initialize(severity, progname, message, timestamp = nil, key = nil)
      @timestamp = timestamp || get_timestamp
      @severity = severity
      @progname = progname
      @message = message
      @key = key || SecureRandom.hex
    end

    def to_h
      {
        message: @message,
        progname: @progname,
        severity: @severity,
        timestamp: @timestamp,
        key: @key
      }
    end

    def to_json(opts=nil)
      JSON.fast_generate(to_h,opts)
    end

    def self.from_json(json)
      parsed = ::JSON.parse(json)
      new( parsed["severity"],
            parsed["progname"],
            parsed["message"],
            parsed["timestamp"],
            parsed["key"] )
    end

    protected

    def get_timestamp
      (Time.new.to_f * 1000).to_i
    end
  end
end
