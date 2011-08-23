module Awsborn
  class LoadBalancer

    include Awsborn::AwsConstants
    attr_accessor :name, :only, :except, :region, :listeners, :sticky_cookies, :health_check_config, :dns_alias

    DEFAULT_LISTENERS = [ { :protocol => :http, :load_balancer_port => 80, :instance_port => 80} ]
    DEFAULT_HEALTH_CONFIG = {
      :healthy_threshold => 10,
      :unhealthy_threshold => 2,
      :target => "TCP:80",
      :timeout => 5,
      :interval => 30
    }

    def initialize (name, options={})
      @name = name
      @only   = options[:only] || []
      @except = options[:except] || []
      @region = zone_to_aws_region(options[:region])
      @listeners = options[:listeners] || DEFAULT_LISTENERS
      @sticky_cookies = options[:sticky_cookies] || []
      @health_check_config = DEFAULT_HEALTH_CONFIG.merge(options[:health_check] || {})
      @dns_alias = options[:dns_alias]
    end

    def elb
      @elb ||= Elb.new(@region)
    end

    def aws_dns_name
      elb.dns_name(@name)
    end

    def instances
      elb.instances(@name)
    end

    def canonical_hosted_zone_name_id
      elb.canonical_hosted_zone_name_id(@name)
    end

    def instances= (new_instances)
      previous_instances = self.instances
      register_instances(new_instances - previous_instances)
      deregister_instances(previous_instances - new_instances)
    end

    def zones
      elb.zones(@name)
    end

    def zones= (new_zones)
      previous_zones = self.zones
      enable_zones(new_zones - previous_zones)
      disable_zones(previous_zones - new_zones)
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

    def health_status
      elb.health_status(@name)
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

    def update_health_config
      elb.configure_health_check(@name, @health_check_config)
    end

    def launch_or_update (running_servers)
      launch unless running?

      set_instances_to_selected(running_servers)
      update_settings

      configure_dns if @dns_alias
    end

    def configure_dns
      route53.create_zone @dns_alias unless route53.zone_exists?(@dns_alias)
      case route53.alias_target(@dns_alias)
      when aws_dns_name
        # It is already good
      when nil
        route53.add_alias_record(:alias => @dns_alias, :lb_fqdn => aws_dns_name, :lb_zone => canonical_hosted_zone_name_id)
      else
        route53.remove_alias_records(@dns_alias)
        route53.add_alias_record(:alias => @dns_alias, :lb_fqdn => aws_dns_name, :lb_zone => canonical_hosted_zone_name_id)
      end
    end

    def route53
      @route53 ||= Route53.new
    end

    def dns_info
      if dns_alias
        route53.zone_for(dns_alias)
      end
    end

    protected

    def set_instances_to_selected (running_servers)
      servers_to_be_balanced = select_servers(running_servers)
      self.instances = servers_to_be_balanced.map {|s| s.instance_id }
      self.zones     = servers_to_be_balanced.map {|s| symbol_to_aws_zone(s.zone) }.uniq
    end

    def select_servers (servers)
      servers = servers.select {|s| @only.include?(s.name)}    unless @only.empty?
      servers = servers.reject {|s| @except.include?(s.name)}  unless @except.empty?
      servers
    end

    def update_settings
      update_listeners
      update_sticky_cookies
      update_health_config
    end

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
