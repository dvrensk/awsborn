$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'awsborn'
require 'spec'
require 'spec/autorun'

require 'rubygems'
require 'webmock/rspec'
include WebMock
WebMock.disable_net_connect!

Spec::Runner.configure do |config|
  
end
