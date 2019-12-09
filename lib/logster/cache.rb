# frozen_string_literal: true

module Logster
  class Cache
    def initialize(age = 2)
      @age = age
      @hash = {}
    end

    def fetch(key)
      if !@hash.key?(key) || @hash[key][:created_at] + @age < Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @hash[key] = { data: yield, created_at: Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      end
      @hash[key][:data]
    end

    def clear(key)
      @hash.delete(key)
    end
  end
end
