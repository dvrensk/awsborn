require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "awsborn"
    gem.description = %Q{Awsborn lets you define and launch a server cluster on Amazon EC2.}
    gem.summary = %Q{Awsborn defines servers as instances with a certain disk volume, which makes it easy to restart missing servers.}
    gem.email = "david@icehouse.se"
    gem.homepage = "http://github.com/icehouse/awsborn"
    gem.authors = ["David Vrensk", "Jean-Louis Giordano"]
    gem.add_dependency "icehouse-right_aws", ">= 2.2.0"
    gem.add_dependency "json_pure", ">= 1.2.3"
    gem.add_dependency "rake"
    gem.add_development_dependency "rspec", ">= 2.6.0"
    gem.add_development_dependency "webmock", ">= 1.3.0"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new do |t|
  t.rspec_opts = ["-c", "-f progress", "-r ./spec/spec_helper.rb"]
  t.pattern = 'spec/**/*_spec.rb'
end

RSpec::Core::RakeTask.new(:rcov) do |t|
  t.rcov_opts =  %q[--exclude "spec"]
end

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "awsborn #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
