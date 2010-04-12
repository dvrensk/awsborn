module Awsborn
  class Server
    
    class << self
      def image_id (*args)
        unless args.empty?
          @image_id = args.first
          @sudo_user = args.last[:sudo_user] if args.last.is_a?(Hash)
        end
        @image_id
      end
      def instance_type (*args)
        @instance_type = args.first unless args.empty?
        @instance_type
      end
      def security_group (*args)
        @security_group = args.first unless args.empty?
        @security_group
      end
      def keys (*args)
        @keys = args.first unless args.empty?
        @keys
      end
      def sudo_user (*args)
        @sudo_user = args.first unless args.empty?
        @sudo_user
      end
      def bootstrap_script (*args)
        @bootstrap_script = args.first unless args.empty?
        @bootstrap_script
      end
      
      def cluster (&block)
        ServerCluster.build self, &block
      end
    end

    def initialize (name, options = {})
      @name = name
      @options = options.dup
    end
    
    def start (key_pair)
      launch_instance
      install_ssh_keys(key_pair)
      associate_address
      bootstrap
      attach_volumes
    end

    def launch_instance
      @launch_response = ec2.launch_instance(image_id,
        :instance_type => constant(instance_type),
        :availability_zone => constant(zone),
        :key_name => key_pair.name,
        :group_ids => security_group
      )
      logger.debug @launch_response

      Awsborn.wait_for("instance #{instance_id} to start", 10) { instance_running? }
    end
    
    def one_of_my_disks_is_attached_to_a_running_instance?
      vol_id = disk.values.first
      description = ec2.describe_volumes(vol_id)
      if description.first[:aws_status] == 'in-use'
        @instance_id = description.first[:aws_instance_id]
        true
      else
        false
      end
    end
    alias :running? :one_of_my_disks_is_attached_to_a_running_instance?

    def instance_running?
      describe_instance![:aws_state] == 'running'
    end

    def describe_instance!
      @describe_instance = nil
      logger.debug describe_instance
      describe_instance
    end
    
    def describe_instance
      @describe_instance ||= ec2.describe_instance(instance_id)
    end

    def associate_address
      ec2.associate_address(instance_id, elastic_ip)
      prepare_known_hosts elastic_ip
    end

    def bootstrap
      if bootstrap_script
        script = path_relative_to_script(bootstrap_script)
        basename = File.basename(script)
        system "scp #{script} root@#{elastic_ip}:/tmp"
        system "ssh root@#{elastic_ip} 'cd /tmp; chmod 700 #{basename}; ./#{basename}"
      end
    end
    
    def attach_volumes
      disk.each_pair do |device, volume|
        device = "/dev/#{device}" if device.is_a?(Symbol) || ! device.match('/')
        res = ec2.attach_volume(volume, instance_id, device)
      end
    end

    def install_ssh_keys (temp_key_pair)
      describe_instance!
      raise ArgumentError, "No hostname for instance #{instance_id}" if aws_dns_name.empty?
      prepare_known_hosts aws_dns_name
      cmd = "ssh -i #{temp_key_pair.path} #{sudo_user}@#{aws_dns_name} 'cat > .ssh/authorized_keys'"
      logger.info cmd
      IO.popen(cmd, "w") do |pipe|
        pipe.puts key_data
      end
      system("ssh -i #{temp_key_pair.path} #{sudo_user}@#{aws_dns_name} 'sudo cp .ssh/authorized_keys /root/.ssh/authorized_keys'")
    end

    def prepare_known_hosts (host_name)
      tries = 0
      begin
        tries += 1
        try_prepare_known_hosts(host_name)
      rescue SecurityError => e
        logger.warn e.message
        if tries < 5
          logger.warn "Sleeping, try #{tries}"
          sleep([2**tries, 15].min)
          retry
        end
      end
    end
    
    def try_prepare_known_hosts (host_name)
      console_fingerprint = rsa_fingerprint
      host_ip = Resolv.getaddress host_name
      [host_name, host_ip].each { |e| remove_from_known_hosts(e) }
      tmp = Tempfile.new "awsborn"
      tmp.close
      system "ssh-keyscan -t rsa #{host_name} #{host_ip} > #{tmp.path} 2>/dev/null"
      fp1, fp2 = `ssh-keygen -l -f #{tmp.path}`.split("\n")
      if fp1.nil? || fp2.nil?
        raise SecurityError, "fp1 = #{fp1.inspect}, fp2 = #{fp2.inspect}"
      elsif fp1.split[1] != fp2.split[1]
        raise SecurityError, "Fingerprints do not match:\n#{fp1} (#{host_name})\n#{fp2} (#{host_ip})!"
      elsif fp1.split[1] != console_fingerprint
        raise SecurityError, "Fingerprints do not match:\n#{fp1} (#{host_name})\n#{console_fingerprint} (EC2 Console)!"
      end
      system "cat #{tmp.path} >> #{ENV['HOME']}/.ssh/known_hosts"
    end

    def `(cmd)
      logger.debug cmd
      out = super
      logger.debug out
      out
    end
    
    def system (cmd)
      logger.debug cmd
      super
    end
    
    def rsa_fingerprint
      # ec2: -----BEGIN SSH HOST KEY FINGERPRINTS-----
      # ec2: 2048 7a:e9:eb:41:b7:45:b1:07:30:ad:13:c5:a9:2a:a1:e5 /etc/ssh/ssh_host_rsa_key.pub (RSA)
      regexp = %r{BEGIN SSH HOST KEY FINGERPRINTS.*((?:[0-9a-f]{2}:){15}[0-9a-f]{2}) /etc/ssh/ssh_host_rsa_key.pub }m
      Awsborn.wait_for "console output", 15, 420 do
        console = ec2.get_console_output(instance_id)
        if console.any?
          fingerprint = console[regexp, 1]
          if ! fingerprint
            logger.error "*** SSH RSA fingerprint not found ***"
            logger.error lines
            logger.error "*** SSH RSA fingerprint not found ***"
          end
        end
        fingerprint
      end
    end

    def remove_from_known_hosts (host)
      system "ssh-keygen -R #{host} > /dev/null 2>&1"
    end
    
    
    def key_data
      key_file_pattern = path_relative_to_script('keys/*')
      Dir[key_file_pattern].inject([]) do |memo,file_name|
        memo + File.readlines(file_name).map { |line| line.chomp }
      end.join("\n")
    end
    
    def path_relative_to_script (path)
      File.join(File.dirname(File.expand_path($0)), path)
    end
    
    def start_sequence
      install_ssh_keys
      install_chef_solo
      run_recipes
    end
    
    def ec2
      @ec2 ||= Ec2.new(zone)
    end
    
    begin :accessors
      def zone
        @options[:zone]
      end
      def disk
        @options[:disk]
      end
      def image_id
        self.class.image_id
      end
      def instance_type
        @options[:instance_type] || self.class.instance_type
      end
      def security_group
        @options[:security_group] || self.class.security_group
      end
      def sudo_user
        @options[:sudo_user] || self.class.sudo_user
      end
      def bootstrap_script
        @options[:bootstrap_script] || self.class.bootstrap_script
      end
      def elastic_ip
        @options[:ip]
      end
      def instance_id
        @instance_id ||= @launch_response[:aws_instance_id]
      end
      def aws_dns_name
        describe_instance[:dns_name]
      end
      def launch_time
        xml_time = describe_instance[:aws_launch_time]
        logger.debug xml_time
        Time.xmlschema(xml_time)
      end
      
    end
    
    def constant (symbol)
      {
        :us_east_1a => "us-east-1a",
        :us_east_1b => "us-east-1b",
        :us_east_1c => "us-east-1c",
        :us_west_1a => "us-west-1a",
        :us_west_1b => "us-west-1b",
        :eu_west_1a => "eu-west-1a",
        :eu_west_1b => "eu-west-1b",
        :m1_small   => "m1.small",
        :m1_large   => "m1.large" ,
        :m1_xlarge  => "m1.xlarge",
        :m2_2xlarge => "m2.2xlarge",
        :m2_4xlarge => "m2.4xlarge",
        :c1_medium  => "c1.medium",
        :c1_xlarge  => "c1.xlarge"
      }[symbol]
    end

    def logger
      @logger ||= Awsborn.logger
    end
    
  end

end
