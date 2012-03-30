module Awsborn
  module AwsConstants

    AVAILABILITY_ZONES = %w[
      us-east-1a us-east-1b us-east-1c us-east-1d
      us-west-1a us-west-1b us-west-1c
      eu-west-1a eu-west-1b eu-west-1c
      ap-southeast-1a ap-southeast-1b
      ap-northeast-1a ap-northeast-1b
    ]
    REGIONS = AVAILABILITY_ZONES.map{|z| z.sub(/[a-z]$/,'') }.uniq
    INSTANCE_TYPES_32_BIT = %w[m1.small c1.medium t1.micro]
    INSTANCE_TYPES_64_BIT = %w[
      m1.small m1.medium m1.large m1.xlarge
      m2.xlarge m2.2xlarge m2.4xlarge
      c1.medium c1.xlarge
      cc1.4xlarge cc2.8xlarge
      t1.micro]
    INSTANCE_TYPES = (INSTANCE_TYPES_32_BIT + INSTANCE_TYPES_64_BIT).uniq
    SYMBOL_CONSTANT_MAP = (AVAILABILITY_ZONES + INSTANCE_TYPES).inject({}) { |memo,str| memo[str.tr('-.','_').to_sym] = str; memo }

    def endpoint_for_zone_and_service (zone, service)
      region = zone_to_aws_region(zone)
      case service
      when :ec2 then "https://#{region}.ec2.amazonaws.com"
      when :elb then "https://#{region}.elasticloadbalancing.amazonaws.com"
      end
    end

    def zone_to_aws_region (zone)
      region = zone.to_s.sub(/[a-z]$/,'').tr('_','-')
      raise UnknownConstantError, "Unknown region: #{region} for zone: #{zone}" unless REGIONS.include? region
      region
    end

    def symbol_to_aws_zone (symbol)
      zone = symbol.to_s.tr('_','-')
      raise UnknownConstantError, "Unknown availability zone: #{zone}" unless AVAILABILITY_ZONES.include? zone
      zone
    end

    def aws_zone_to_symbol (zone)
      raise UnknownConstantError, "Unknown availability zone: #{zone}" unless AVAILABILITY_ZONES.include? zone
      zone.to_s.tr('-','_').to_sym
    end

    def symbol_to_aws_instance_type (symbol)
      type = symbol.to_s.tr('_','.')
      raise UnknownConstantError, "Unknown instance type: #{type}" unless INSTANCE_TYPES.include? type
      type
    end

    def aws_instance_type_to_symbol (type)
      raise UnknownConstantError, "Unknown instance type: #{type}" unless INSTANCE_TYPES.include? type
      type.to_s.tr('.','_').to_sym
    end

    def aws_constant (symbol)
      SYMBOL_CONSTANT_MAP[symbol] || raise(UnknownConstantError, "Unknown constant: #{symbol}")
    end
  end

  class UnknownConstantError < Exception; end
end
