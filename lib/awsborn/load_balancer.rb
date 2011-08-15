module Awsborn
  class LoadBalancer

    include Awsborn::AwsConstants
    attr_accessor :name, :only, :except, :region, :listeners, :sticky_cookies

    DEFAULT_LISTENERS = [ { :protocol => :http, :load_balancer_port => 80, :instance_port => 80} ]
    def initialize (name, options={})
      @name = name
      @only   = options[:only] || []
      @except = options[:except] || []
      @region = zone_to_aws_region(options[:region])
      @listeners = options[:listeners] || DEFAULT_LISTENERS
      @sticky_cookies = options[:sticky_cookies] || []
      launch unless running?
    end

    def elb
      @elb ||= Elb.new(@region)
    end

    def dns_name
      elb.dns_name(@name)
    end

    def instances
      elb.instances(@name)
    end

    def instances= (new_instances)
      previous_instances = self.instances
      register_instances(new_instances - previous_instances)
      deregister_instances(previous_instances - new_instances)
      self.instances
    end

    def zones
      elb.zones(@name)
    end

    def zones= (new_zones)
      previous_zones = self.zones
      enable_zones(new_zones - previous_zones)
      disable_zones(previous_zones - new_zones)
      self.zones
    end

    def description
      elb.describe_load_balancer(@name)
    end

    def running?
      elb.running?(@name)
    end

    def launch
      elb.create_load_balancer(@name)
    end


    def update_listeners
      elb.set_load_balancer_listeners(@name, @listeners)
    end

    def update_sticky_cookies
      elb.remove_all_cookie_policies(@name)
      @sticky_cookies.each do |sc|
        raise "Option :ports is missing for #{sc.inspect}" if sc[:ports].nil?

        case sc[:policy]
        when :disabled
          set_disabled_cookie_policy(sc[:ports])
        when :lb_generated
          set_lb_cookie_policy(sc[:ports], sc[:expiration_period])
        when :app_generated
          set_app_cookie_policy(sc[:ports], sc[:cookie_name])
        else
          raise "unknown policy #{sc.inspect}. Accepted policies => :disabled, :lb_generated, :app_generated"
        end
      end
    end

    def update_with (new_servers)
      servers_to_be_balanced = new_servers
      servers_to_be_balanced =
        servers_to_be_balanced.select{|s| @only.include?(s.name)}    unless @only.empty?
      servers_to_be_balanced =
        servers_to_be_balanced.reject{|s| @except.include?(s.name)}  unless @except.empty?

      self.instances = servers_to_be_balanced.map{|s| s.instance_id }
      self.zones     = servers_to_be_balanced.map{|s| symbol_to_aws_zone(s.zone) }.uniq

      update_listeners
      update_sticky_cookies

      self.description
    end

    protected

    def set_disabled_cookie_policy(ports)
      # Do nothing
    end

    def set_app_cookie_policy(ports, cookie_name)
      raise ":cookie_name is missing" if cookie_name.nil?
      elb.set_app_sticky_cookie(@name, ports, cookie_name)
    end

    def set_lb_cookie_policy(ports, expiration_period)
      raise ":expiration_period is missing" if expiration_period.nil?
      elb.set_lb_sticky_cookie(@name, ports, expiration_period.to_i)
    end

    def register_instances (instances)
      elb.register_instances(@name, instances) unless instances.empty?
    end

    def deregister_instances (instances)
      elb.deregister_instances(@name, instances) unless instances.empty?
    end

    def enable_zones (zones)
      elb.enable_zones(@name, zones) unless zones.empty?
    end

    def disable_zones (zones)
      elb.disable_zones(@name, zones) unless zones.empty?
    end

  end
end
