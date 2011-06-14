$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'awsborn'
require 'rspec'

require 'rubygems'
require 'webmock/rspec'
include WebMock::API
WebMock.disable_net_connect!
