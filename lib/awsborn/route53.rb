module Awsborn
  class Route53
    extend Forwardable
    def_delegators :Awsborn, :logger
    include Awsborn::AwsConstants
    attr_reader :connection

    def connection
      unless @connection
        @connection = RightAws::Route53Interface.new(Awsborn.access_key_id, Awsborn.secret_access_key, :logger => Awsborn.logger)
      end
      @connection
    end

    def initialize (zone = nil)
    end

    def zone_exists? (name)
      !! zone_overview_for(name)
    end

    def zone_for (name)
      zone_id = zone_id_for(name)
      connection.get_hosted_zone(zone_id) if zone_id
    end

    def zone_id_for (name)
      overview = zone_overview_for(name)
      overview[:aws_id] if overview
    end

    def create_zone (name)
      connection.create_hosted_zone({:name => with_final_dot(name), :config => {:comment => ''}})
    end

    def alias_target (name)
      name = with_final_dot(name)
      zone = zone_id_for(name)
      alias_record = connection.list_resource_record_sets(zone).detect { |rr| rr[:name] == name && rr[:alias_target] }
      alias_record && alias_record[:alias_target]
    end

    def add_alias_record (options)
      name = with_final_dot(options[:alias])
      zone = zone_id_for(name)
      alias_target = { :hosted_zone_id => options[:lb_zone], :dns_name => options[:lb_fqdn] }
      alias_record = { :name => options[:alias], :type => 'A', :alias_target => alias_target }
      connection.create_resource_record_sets(zone, [alias_record])
    end

    def remove_alias_records (name)
      name = with_final_dot(name)
      zone = zone_id_for(name)
      alias_records = connection.list_resource_record_sets(zone).select { |rr| rr[:name] == name && rr[:alias_target] }
      connection.delete_resource_record_sets(zone, alias_records)
    end

    private

    def zone_overview_for (name)
      name = with_final_dot(name)
      zones = connection.list_hosted_zones
      zone = zones.detect { |zone| zone[:name] == name }
    end

    def with_final_dot (name)
      name =~ /\.$/ ? name : "#{name}."
    end
  end
end
