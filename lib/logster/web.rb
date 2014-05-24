require 'logster/middleware/viewer'

class Logster::Web
  def self.call(env)
    @middleware ||= Logster::Middleware::Viewer.new(nil)
    @middleware.call(env)
  end
end
