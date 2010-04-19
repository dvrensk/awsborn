require 'forwardable'
require 'resolv'
require 'tempfile'

require 'rubygems'
require 'right_aws'
require 'json'

# %w[
#   awsborn
#   server
#   server_cluster
#   extensions/proc
#   ].each { |e| require File.dirname(__FILE__) + "/awsborn/#{e}" }

require 'pp'

Dir[File.join(File.dirname(__FILE__), 'awsborn/**/*.rb')].sort.each { |lib| require lib }