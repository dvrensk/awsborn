module Awsborn
  class Elb
    extend Forwardable
    def_delegators :Awsborn, :logger
    include Awsborn::AwsConstants
    attr_accessor :region, :endpoint

    def connection
      unless @connection
        env_ec2_url = ENV['ELB_URL']
        begin
          ENV['ELB_URL'] = @endpoint
          @connection = RightAws::ElbInterface.new(
            Awsborn.access_key_id,
            Awsborn.secret_access_key,
            :logger => Awsborn.logger
          )
        ensure
          ENV['ELB_URL'] = env_ec2_url
        end
      end
      @connection
    end

    def initialize (zone)
      @region = zone_to_aws_region(zone)
      @endpoint = endpoint_for_zone_and_service(@region, :elb)
    end

    def describe_load_balancer (balancer_name)
      connection.describe_load_balancers(balancer_name).first
    end

    def running? (balancer_name)
      describe_load_balancer(balancer_name)
      true
    rescue RightAws::AwsError
      false
    end

    def dns_name (balancer_name)
      describe_load_balancer(balancer_name)[:dns_name]
    end

    def instances (balancer_name)
      describe_load_balancer(balancer_name)[:instances]
    end

    def zones (balancer_name)
      describe_load_balancer(balancer_name)[:availability_zones]
    end

    def create_load_balancer (balancer_name)
      logger.debug "Creating load balancer #{balancer_name}"
      connection.create_load_balancer(balancer_name, [@region+'a'], [])
    end

    def set_load_balancer_listeners (balancer_name, listeners)
      logger.debug "Setting listeners on load balancer #{balancer_name}"
      description = describe_load_balancer(balancer_name)
      previous_ports = description[:listeners].map{|i| i[:instance_port]}
      connection.delete_load_balancer_listeners(balancer_name, *previous_ports) unless previous_ports.empty?
      connection.create_load_balancer_listeners(balancer_name, listeners)
    end

    def set_lb_cookie_policy (balancer_name, ports, expiration_period)
      logger.debug "Setting cookie policies for ports #{ports.inspect} on load balancer #{balancer_name}"
      policy_name = "lb-#{balancer_name}-#{expiration_period}".tr('_','-')
      unless existing_lb_cookie_policies(balancer_name).include?(policy_name)
        connection.create_lb_cookie_stickiness_policy(balancer_name, policy_name, expiration_period)
      end
      ports.each do |port|
        connection.set_load_balancer_policies_of_listener(balancer_name, port, policy_name)
      end
    end

    def set_app_cookie_policy (balancer_name, ports, cookie_name)
      logger.debug "Setting cookie policies for ports #{ports.inspect} on load balancer #{balancer_name}"
      policy_name = "app-#{balancer_name}-#{cookie_name}".tr('_','-')
      unless existing_app_cookie_policies(balancer_name).include?(policy_name)
        connection.create_app_cookie_stickiness_policy(balancer_name, policy_name, cookie_name)
      end
      ports.each do |port|
        connection.set_load_balancer_policies_of_listener(balancer_name, port, policy_name)
      end
    end

    def remove_all_cookie_policies(balancer_name)
      description = describe_load_balancer(balancer_name)
      description[:listeners].each do |listener|
        connection.set_load_balancer_policies_of_listener(balancer_name, listener[:load_balancer_port])
      end
    end

    def register_instances (balancer_name, instances)
      logger.debug "Registering instances #{instances.inspect} on load balancer #{balancer_name}"
      connection.register_instances_with_load_balancer(balancer_name, *instances)
    end

    def deregister_instances (balancer_name, instances)
      logger.debug "De-registering instances #{instances.inspect} on load balancer #{balancer_name}"
      connection.deregister_instances_with_load_balancer(balancer_name, *instances)
    end

    def enable_zones (balancer_name, zones)
      logger.debug "Enabling zones #{zones.inspect} on load balancer #{balancer_name}"
      connection.enable_availability_zones_for_load_balancer(balancer_name, *zones)
    end

    def disable_zones (balancer_name, zones)
      logger.debug "Disabling zones #{zones.inspect} on load balancer #{balancer_name}"
      connection.disable_availability_zones_for_load_balancer(balancer_name, *zones)
    end

    protected

    def existing_app_cookie_policies (balancer_name)
      description = describe_load_balancer(balancer_name)
      description[:app_cookie_stickiness_policies].map {|p| p[:policy_name]}.uniq
    end

    def existing_lb_cookie_policies (balancer_name)
      description = describe_load_balancer(balancer_name)
      description[:lb_cookie_stickiness_policies].map {|p| p[:policy_name]}.uniq
    end
  end
end
