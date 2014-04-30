require 'logster/logger'

module Logster
end

if defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i >= 3
  require 'logster/rails/railtie'
end
