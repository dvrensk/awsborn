module Awsborn
  class GitBranch

    attr_reader :branch

    def initialize (branch)
      require 'git'
      @branch = branch
    end
    
    def file (path)
      path, file = File.split(path)

      repo = Git.open(root)
      tree = repo.branches[branch].gcommit.gtree
      path.each { |dir| tree = tree.subtrees[dir] }
      tree.blobs[file].contents
    end

    protected

    def root
      dir = File.expand_path('.')
      while dir != '/'
        return dir if File.directory?(File.join(dir, '.git'))
        dir = File.dirname(dir)
      end
    end
  end
end