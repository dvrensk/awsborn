module Awsborn
  module Chef
    module Rake

      def default_cluster
        default_klass = Awsborn::Server.children.first
        default_klass.clusters.first
      end

      desc "Default: Start all servers (if needed) and deploy with chef."
      task :all => [:start, "chef:run"]
      task :default => :all

      desc "Like 'all' but with chef debugging on."
      task :debug => ["chef:set_chef_debug", :all]

      desc "Start all servers (or host=name1,name2) but don't run chef."
      task :start do |t,args|
        hosts = args[:host] && args[:host].split(',')
        default_cluster.launch hosts
      end

      desc "Run chef on all servers (or host=name1,name2)."
      task :chef => "chef:run"

      namespace :chef do
        task :run => [:check_syntax] do |t,args|
          hosts = args[:host] && args[:host].split(',')
          default_cluster.each do |server|
            server.cook if hosts.nil? || hosts.include?(server.name.to_s)
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

      def create_cookbook(dir)
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
    end
  end
end