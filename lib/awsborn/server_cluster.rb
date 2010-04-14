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
      running, missing = @instances.partition { |e| e.running? }
      refresh_running(running) if running.any?
      start_missing_instances(missing) if missing.any?
    end

    def refresh_running (instances)
      instances.each { |e| e.refresh }
    end

    def start_missing_instances (instances)
      generate_key_pair(instances)
      instances.each { |e| e.start(@key_pair) }
      delete_key_pair(instances)
    end

    def generate_key_pair (instances)
      @key_pair = instances.first.ec2.generate_key_pair
    end

    def delete_key_pair (instances)
      instances.first.ec2.delete_key_pair(@key_pair)
    end
    
    def each (&block)
      @instances.each &block
    end

    def [] (name)
      @instances.detect { |i| i.name == name }
    end
    
    protected
    
    def add_domain_to_ip (hash)
      if @domain && hash.has_key?(:ip) && ! hash[:ip].include?('.')
        ip = [hash[:ip], @domain].join('.')
        hash.merge(:ip => ip)
      else
        hash
      end
    end
    
  end
end
