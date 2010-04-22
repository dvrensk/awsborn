module Awsborn
  module Chef
    module Rake

      def default_cluster
        default_klass = Awsborn::Server.children.first
        default_klass.clusters.first
      end

      desc "Start all servers (if needed) and deploy with chef"
      task :default => [:start, :chef]

      desc "Start all servers"
      task :start do
        default_cluster.launch
      end

      desc "Run chef on all servers"
      task :chef => [:check_syntax] do
        default_cluster.each do |server|
          server.cook
        end
      end
      task :cook => [:chef]

      desc "Check your cookbooks and config files for syntax errors"
      task :check_syntax do
        Dir["**/*.rb"].each do |recipe|
          RakeFileUtils.verbose(false) do
            sh %{ruby -c #{recipe} > /dev/null} do |ok, res|
              raise "Syntax error in #{recipe}" if not ok 
            end
          end
        end
      end

      desc "Create a new cookbook (with cookbook=name)"
      task :new_cookbook do
        create_cookbook("cookbooks")
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