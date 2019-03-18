module Logster
  class Cache
    def initialize(age = 2)
      @age = age
      @hash = { created_at: Time.now.to_f }
    end

    def fetch
      if !@hash.key?(:data) || @hash[:created_at] + @age < Time.now.to_f
        @hash[:data] = yield
        @hash[:created_at] = Time.now.to_f
      end
      @hash[:data]
    end
  end
end
