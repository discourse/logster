require 'logster/middleware/viewer'

class Logster::Web
  class FourOhFour
    def call(env)
      [404, {}, ["not found"]]
    end
  end

  def self.call(env)
    @middleware ||= Logster::Middleware::Viewer.new(FourOhFour.new)
    @middleware.call(env)
  end
end
