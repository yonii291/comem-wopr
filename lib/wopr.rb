require 'json'

module Wopr
  VERSION = JSON.parse(File.read(File.join(File.dirname(__FILE__), '..', 'package.json')))['version']
end

require_relative './wopr/action'
require_relative './wopr/ai'
require_relative './wopr/config'