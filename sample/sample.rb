require 'logster'
require 'logster/middleware/reporter'
require 'logster/middleware/viewer'

require 'sinatra'
require 'sinatra/base'

class Sample < Sinatra::Base
  use Rack::Logster::Reporter
  use Rack::Logster::Viewer

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
end
