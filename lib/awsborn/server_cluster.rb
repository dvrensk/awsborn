module Awsborn
  class ServerCluster
    def self.build (klass, &block)
      cluster = new(klass)
      block.bind(cluster, 'cluster').call
      cluster
    end

    def initialize (klass)
      @klass = klass
      @instances = []
    end
    
    def domain (*args)
      @domain = args.first unless args.empty?
      @domain
    end
    
    def server (name, options = {})
      options = add_domain_to_ip(options)
      instance = @klass.new name, options
      @instances << instance
    end

    def launch
      start_missing_instances
    end

    def start_missing_instances
      to_start = find_missing_instances
      return if to_start.empty?
      generate_key_pair(to_start)
      to_start.each { |e| e.start(@key_pair) }
    end

    def find_missing_instances
      @instances.reject { |e| e.running? }
    end

    def generate_key_pair (instances)
      @key_pair = instances.first.ec2.generate_key_pair
    end

    def each (&block)
      @instances.each &block
    end

    def [] (name)
      @instances.detect { |i| i.name == name }
    end
    
    protected
    
    def add_domain_to_ip (hash)
      if @domain && hash.has_key?(:ip)
        ip = [hash[:ip], @domain].join('.')
        hash.merge(:ip => ip)
      else
        hash
      end
    end
    
  end
end
