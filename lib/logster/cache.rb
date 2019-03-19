module Logster
  class Cache
    def initialize(age = 2)
      @age = age
      @hash = { created_at: Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    end

    def fetch
      if !@hash.key?(:data) || @hash[:created_at] + @age < Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @hash[:data] = yield
        @hash[:created_at] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
      @hash[:data]
    end

    def clear
      @hash.delete(:data)
    end
  end
end
