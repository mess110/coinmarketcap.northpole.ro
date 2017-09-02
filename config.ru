require './app'
root = ::File.dirname(__FILE__)
logfile = ::File.join(root,'logs','requests.log')

require 'logger'
class ::Logger; alias_method :write, :<<; end
logger  = ::Logger.new(logfile,'weekly')

use Rack::CommonLogger, logger
# use Rack::Reloader, 0
run Ki::Ki.new
