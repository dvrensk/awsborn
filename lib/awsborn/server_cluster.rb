module Awsborn
  class ServerCluster
    include Enumerable

    attr_accessor :name, :load_balancers

    def self.build (klass, name, &block)
      cluster = new(klass, name)
      block.bind(cluster, 'cluster').call
      cluster
    end

    def self.clusters
      @clusters ||= []
    end

    def self.cluster_for (instance)
      clusters.each do |cluster|
        return cluster if cluster.detect { |i| i == instance }
      end
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
      @load_balancers = []
      self.class.clusters << self
    end

    def domain (*args)
      @domain = args.first unless args.empty?
      @domain
    end

    def load_balancer (name, options={})
      options = add_domain_to_dns_alias(options)
      @load_balancers << Awsborn::LoadBalancer.new(name, options)
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
      update_load_balancing(running) unless @load_balancers.empty?
    end

    def refresh_running (instances)
      instances.each { |e| e.refresh }
    end

    def start_missing_instances (instances)
      generate_key_pair(instances)
      instances.each { |e| e.start(@key_pair) }
      delete_key_pair(instances)
    end

    def update_load_balancing(running)
      @load_balancers.each do |lb|
        lb.launch_or_update(running)
      end
    end

    def load_balancer_info
      info = load_balancers.map do |lb|
        lb.dns_info
      end.compact
      info.empty? ? nil : info
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
      add_domain_to_key(:ip, hash)
    end
    def add_domain_to_dns_alias (hash)
      add_domain_to_key(:dns_alias, hash)
    end
    def add_domain_to_key (key, hash)
      if @domain && hash.has_key?(key) && ! hash[key].include?('.')
        expanded = [hash[key], @domain].join('.')
        hash.merge(key => expanded)
      else
        hash
      end
    end
    
  end
end
