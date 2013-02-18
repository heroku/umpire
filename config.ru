$:.unshift File.dirname(__FILE__) + '/lib'
require 'umpire'
require 'umpire/web'

run Umpire::Web.new