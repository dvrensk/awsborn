module Awsborn
  class Ec2
    extend Forwardable
    def_delegators :connection, :describe_volumes, :attach_volume

    def connection
      unless @connection
        env_ec2_url = ENV['EC2_URL']
        begin
          ENV['EC2_URL'] = @endpoint
          @connection = ::RightAws::Ec2.new(Awsborn.access_key_id,
                                            Awsborn.secret_access_key,
                                            :logger => Awsborn.logger)
        ensure
          ENV['EC2_URL'] = env_ec2_url
        end
      end
      @connection
    end      
    
    def initialize (zone)
      @endpoint = case zone
      when :eu_west_1a, :eu_west_1b
        'https://eu-west-1.ec2.amazonaws.com/'
      when :us_east_1a, :us_east_1b
        'https://us-east-1.ec2.amazonaws.com'
      else
        'https://ec2.amazonaws.com'
      end
    end

    KeyPair = Struct.new :name, :path
    
    def generate_key_pair
      time = Time.now
      key_name = "temp_key_#{time.to_i}_#{time.usec}"
      key_data = connection.create_key_pair(key_name)
      file_path = File.join(ENV['TMP_DIR'] || '/tmp', "#{key_name}.pem")
      File.open file_path, "w", 0600 do |f|
        f.write key_data[:aws_material]
      end
      pp key_data
      KeyPair.new key_name, file_path
    end
    
    def associate_address (instance_id, address)
      unless address.match(/^(\d{1,3}\.){3}\d{1,3}$/)
        address = Resolv.getaddress address
      end
      connection.associate_address(instance_id, address)
    end

    def describe_instance (id)
      connection.describe_instances(id).first
    end

    def launch_instance (*args)
      connection.launch_instances(*args).first
    end
    
    def get_console_output (id)
      output = connection.get_console_output(id)
      output[:aws_output]
    end
    
  end
end