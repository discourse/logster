require 'redis'
require 'logster'
require 'logster/middleware/reporter'
require 'logster/middleware/viewer'
require 'logster/redis_store'

require 'sinatra'
require 'sinatra/base'

# log a few errors
$store = Logster::RedisStore.new

$log = Logster::Logger.new($store)
$log.info "Some info line"
$log.warn "Some warn line"
$log.error "Some error line"

class Sample < Sinatra::Base
  use Logster::Middleware::Reporter, log: $log
  use Logster::Middleware::Viewer, store: $store

  get '/' do

<<HTML
<html>
<head>
</head>
<body>
<h3>Welcome to the sample app:</h3>
<ul>
  <li><a href='/report_error'>Report error</a></li>
  <li><a href='/logs'>View logs</a></li>
</ul>
</body>
</html>
HTML

  end

  get '/report_error' do
    boom
  end

end
