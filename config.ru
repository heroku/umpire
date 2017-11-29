$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "lib")))
require "umpire"
require "umpire/log"
require "umpire/web"
require 'rack/ssl'
require 'rack-timeout'

run Umpire::Web
