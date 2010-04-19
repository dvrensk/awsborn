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
    gem.authors = ["David Vrensk"]
    gem.add_dependency "icehouse-right_aws", ">= 1.11.0"
    gem.add_dependency "json_pure", ">= 1.2.3"
    gem.add_development_dependency "rspec", ">= 1.2.9"
    gem.add_development_dependency "webmock", ">= 0.9.1"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
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
