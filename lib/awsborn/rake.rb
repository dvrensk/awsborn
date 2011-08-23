module Awsborn
  module Chef #:nodoc:
    # Just add a `Rakefile` in the same directory as your server definition file.
    #
    #     require 'awsborn'
    #     include Awsborn::Chef::Rake
    #     require './servers'
    #
    # You are now able to run `rake` to start all servers and run Chef on each of them.
    # Other rake tasks include:
    #
    # * `rake chef` - Run chef on all servers, or the ones specified with `host=name1,name2`.
    # * `rake chef:debug` - Ditto, but with chef's log level set to `debug`.
    # * `rake start` - Start all servers (or host=name1,name2) but don't run `chef`.
    #
    # You can use `server=name1,name2` as a synonym for `host=...`
    #
    module Rake

      desc "Default: Start all servers (if needed) and deploy with chef."
      task :all => [:start, "chef:run"]
      task :default => :all

      desc "Like 'all' but with chef debugging on."
      task :debug => ["chef:set_chef_debug", :all]

      desc "Start all servers (or host=name1,name2) but don't run chef."
      task :start do |t,args|
        c = cluster(args)
        c.launch get_hosts(args)
        info = c.load_balancer_info
        print_required_dns_setting(info) if info
      end

      def print_required_dns_setting (info)
        puts "Make sure those NS records are present in your DNS settings:"
        puts(info.map do |dns_entry|
          dns_entry[:name_servers].map do |ns|
            "#{dns_entry[:name]}\tIN\tNS\t#{ns}."
          end
        end.join("\n"))
      end

      desc "Update .ssh/known_hosts with data from all servers (or host=host1,host2)"
      task :update_known_hosts do |t,args|
        hosts = get_hosts(args)
        cluster(args).each do |server|
          server.running? && server.update_known_hosts if hosts.nil? || hosts.include?(server.name.to_s)
        end
      end

      desc "Run chef on all servers (or host=name1,name2)."
      task :chef => "chef:run"

      namespace :chef do
        task :run => [:check_syntax] do |t,args|
          hosts = get_hosts(args)
          cluster(args).each do |server|
            next unless hosts.nil? || hosts.include?(server.name.to_s)
            puts framed("Running chef on '#{server.name}'")
            server.cook
          end
        end

        desc "Run chef on all servers with log_level debug."
        task :debug => [:set_chef_debug, :run]
        task :set_chef_debug do
          Awsborn.chef_log_level = :debug
        end

        desc "Check your cookbooks and config files for syntax errors."
        task :check_syntax do
          Dir["**/*.rb"].each do |recipe|
            RakeFileUtils.verbose(false) do
              sh %{ruby -c #{recipe} > /dev/null} do |ok, res|
                raise "Syntax error in #{recipe}" if not ok 
              end
            end
          end
        end

        desc "Create a new cookbook (with cookbook=name)."
        task :new_cookbook do
          create_cookbook("cookbooks")
        end
      end

      desc "List running servers"
      task :list do |t,args|
        running = cluster(args).select { |server| server.running? }
        max_name_length = running.map { |server| server.name.to_s.size }.max
        running.each do |server|
          h = server.describe_instance
          puts "%-#{max_name_length}s -- %s -- %s -- %s (%s) %s" %
            [server.name, server.host_name, h[:aws_availability_zone], h[:aws_instance_type], h[:architecture], h[:aws_instance_id]]
        end
      end

      desc "Update chef on the server"
      task :update_chef do |t,args|
        hosts = get_hosts(args)
        cluster(args).each do |server|
          next if hosts && ! hosts.include?(server.name.to_s)
          puts framed("Updating chef on server #{server.name}")
          # Include excplicit path to avoid rvm
          sh "ssh root@#{server.host_name} 'PATH=/usr/sbin:/usr/bin:/sbin:/bin gem install chef --no-ri --no-rdoc'"
        end
      end

      def create_cookbook(dir) #:nodoc:
        raise "Must provide a cookbook=" unless ENV["cookbook"]
        puts "** Creating cookbook #{ENV["cookbook"]}"
        sh "mkdir -p #{File.join(dir, ENV["cookbook"], "attributes")}" 
        sh "mkdir -p #{File.join(dir, ENV["cookbook"], "recipes")}" 
        sh "mkdir -p #{File.join(dir, ENV["cookbook"], "definitions")}" 
        sh "mkdir -p #{File.join(dir, ENV["cookbook"], "libraries")}" 
        sh "mkdir -p #{File.join(dir, ENV["cookbook"], "files", "default")}" 
        sh "mkdir -p #{File.join(dir, ENV["cookbook"], "templates", "default")}" 

        unless File.exists?(File.join(dir, ENV["cookbook"], "recipes", "default.rb"))
          open(File.join(dir, ENV["cookbook"], "recipes", "default.rb"), "w") do |file|
            file.puts <<-EOH
#
# Cookbook Name:: #{ENV["cookbook"]}
# Recipe:: default
#
EOH
          end
        end
      end

      def get_hosts (args) #:nodoc:
        args[:host] && args[:host].split(',') || args[:server] && args[:server].split(',')
      end

      def framed (message) #:nodoc:
        '*' * (4 + message.length) + "\n* #{message} *\n" + '*' * (4 + message.length)
      end

      def cluster (args) #:nodoc:
        name = args[:c] || args[:cluster] || 'cluster 1'
        Awsborn::ServerCluster.clusters.detect { |c| c.name == name } || raise("Could not find cluster named '#{name}'")
      end

    end
  end
end
