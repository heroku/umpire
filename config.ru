require_relative 'lib/umpire'
require 'rack/ssl'
require 'rack-timeout'

run Umpire::Web
