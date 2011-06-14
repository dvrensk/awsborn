module Awsborn
  class ServerCluster
    include Enumerable

    attr_accessor :name

    def self.build (klass, name, &block)
      cluster = new(klass, name)
      block.bind(cluster, 'cluster').call
      cluster
    end

    def self.clusters
      @clusters ||= []
    end

    def self.next_name
      @next_name_counter ||= 1
      old_names = clusters.map { |c| c.name }
      begin
        next_name = "cluster #{@next_name_counter}"
        @next_name_counter += 1
      end while old_names.include?(next_name)
      next_name
    end

    def initialize (klass, name)
      @klass = klass
      @name = name.to_s
      @instances = []
      self.class.clusters << self
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

    def launch (names)
      requested = names.nil? ? @instances : @instances.select { |s| names.include?(s.name.to_s) }
      running, missing = requested.partition { |e| e.running? }
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
