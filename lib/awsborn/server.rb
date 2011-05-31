module Awsborn
  class Server
    
    def initialize (name, options = {})
      @name = name
      @options = options.dup
      self.host_name = elastic_ip
    end
    
    class << self
      attr_accessor :logger, :children, :clusters
      def inherited (klass)
        @children ||= []
        @children << klass
      end
      # Set image_id.  Examples:
      #   image_id 'ami-123123'
      #   image_id 'ami-123123', :sudo_user => 'ubuntu'
      #   image_id :i386 => 'ami-323232', :x64 => 'ami-646464', :sudo_user => 'ubuntu'
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
        @keys = args unless args.empty?
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
      def monitor (*args)
        @monitor = args.first unless args.empty?
        @monitor
      end
      
      def cluster (&block)
        @clusters ||= []
        @clusters << ServerCluster.build(self, &block)
        @clusters.last
      end
      def logger
        @logger ||= Awsborn.logger
      end
    end

    def running?
      map = {}
      disk_volume_ids.each { |vol_id| map[vol_id] = ec2.instance_id_for_volume(vol_id) }
      ids = map.values.uniq
      if ids.size > 1
        raise ServerError, "Volumes for #{self.class.name}:#{name} are connected to several instances: #{map.inspect}"
      end
      ec2.instance_id = ids.first
    end

    def refresh
      start_or_stop_monitoring unless monitor.nil?
      associate_address if elastic_ip
      
      begin
        update_known_hosts
        install_ssh_keys if keys
      rescue SecurityError => e
        logger.warn "Could not update known_hosts for #{name}:"
        logger.warn e
      end
    end
    
    def start_or_stop_monitoring
      if monitor && ! ec2.monitoring?
        ec2.monitor
      elsif ec2.monitoring? && ! monitor
        ec2.unmonitor
      end
    end
    
    def start (key_pair)
      launch_instance(key_pair)

      update_known_hosts
      install_ssh_keys(key_pair) if keys

      if elastic_ip
        associate_address
        update_known_hosts
      end

      bootstrap if bootstrap_script
      attach_volumes
    end

    def launch_instance (key_pair)
      @launch_response = ec2.launch_instance(image_id,
        :instance_type => constant(instance_type),
        :availability_zone => constant(zone),
        :key_name => key_pair.name,
        :group_ids => security_group,
        :monitoring_enabled => monitor
      )
      logger.debug @launch_response

      Awsborn.wait_for("instance #{instance_id} (#{name}) to start", 10) { instance_running? }
      self.host_name = aws_dns_name
    end

    def update_known_hosts
      KnownHostsUpdater.update_for_server self
    end
    
    def install_ssh_keys (temp_key_pair = nil)
      logger.debug "Installing ssh keys on #{name}"
      raise ArgumentError, "No host_name for #{name}" unless host_name
      install_ssh_keys_for_sudo_user_or_root (temp_key_pair)
      copy_sudo_users_keys_to_root if sudo_user
    end

    def install_ssh_keys_for_sudo_user_or_root (temp_key_pair)
      current_key = "-i #{temp_key_pair.path}" if temp_key_pair
      IO.popen("ssh #{current_key} #{sudo_user || 'root'}@#{host_name} 'cat > .ssh/authorized_keys'", "w") do |pipe|
        pipe.puts key_data
      end
    end
    
    def key_data
      Dir[*keys].inject([]) do |memo, file_name|
        memo + File.readlines(file_name).map { |line| line.chomp }
      end.join("\n")
    end

    def copy_sudo_users_keys_to_root
      system("ssh #{sudo_user}@#{host_name} 'sudo cp .ssh/authorized_keys /root/.ssh/authorized_keys'")
    end

    def associate_address
      logger.debug "Associating address #{elastic_ip} to #{name}"
      ec2.associate_address(elastic_ip)
      self.host_name = elastic_ip
    end

    def bootstrap
      logger.debug "Bootstrapping #{name}"
      script = bootstrap_script
      basename = File.basename(script)
      system "scp #{script} root@#{host_name}:/tmp"
      system "ssh root@#{host_name} 'cd /tmp && chmod 700 #{basename} && ./#{basename}'"
    end
    
    def attach_volumes
      logger.debug "Attaching volumes #{disk.values.join(', ')} to #{name}"
      disk.each_pair do |device, str_or_ary|
        volume = str_or_ary.is_a?(Array) ? str_or_ary.first : str_or_ary
        device = "/dev/#{device}" if device.is_a?(Symbol) || ! device.match('/')
        res = ec2.attach_volume(volume, device)
      end
    end

    def cook
      upload_cookbooks
      run_chef
    end

    def upload_cookbooks
      logger.info "Uploading cookbooks to #{host_name}"

      cookbooks_dir = '../cookbooks' # Hard coded for now
      temp_link = File.directory?(cookbooks_dir) && ! File.directory?('cookbooks')
      File.symlink(cookbooks_dir, 'cookbooks') if temp_link

      File.open("config/dna.json", "w") { |f| f.write(chef_dna.to_json) }
      system "rsync -rL --delete --exclude '.*' ./ root@#{host_name}:#{Awsborn.remote_chef_path}"
    ensure
      File.delete("config/dna.json")
      File.delete("cookbooks") if temp_link
    end

    def run_chef
      logger.info "Running chef on #{host_name}"
      # Absolute path to config files to avoid a nasty irrational bug.
      sh "ssh root@#{host_name} \"cd #{Awsborn.remote_chef_path}; chef-solo -l #{Awsborn.chef_log_level} -c #{Awsborn.remote_chef_path}/config/solo.rb -j #{Awsborn.remote_chef_path}/config/dna.json\""
    end

    def ec2
      @ec2 ||= Ec2.new(zone)
    end
    
    begin :accessors
      attr_accessor :name, :logger
      def host_name= (string)
        logger.debug "Setting host_name of #{name} to #{string}"
        @host_name = string
      end
      def host_name
        unless @host_name
          logger.debug 'Looking up DNS name from volume ID'
          self.host_name = aws_dns_name
          logger.debug "got DNS name #{@host_name}"
          update_known_hosts
        end
        @host_name
      end
      def zone
        @options[:zone]
      end
      def disk
        @options[:disk]
      end
      def disk_volume_ids
        disk.values.map { |str_or_ary| str_or_ary.is_a?(Array) ? str_or_ary.first : str_or_ary }
      end
      def format_disk_on_device? (device)
        volume = disk[device.to_sym]
        volume.is_a?(Array) && volume.last == :format
      end
      def image_id
        return @options[:image_id] if @options[:image_id]
        tmp = self.class.image_id
        tmp.is_a?(String) ? tmp : tmp[architecture]
      end
      def architecture
        string = constant(instance_type)
        case
        when INSTANCE_TYPES_32_BIT.include?(string) then :i386
        when INSTANCE_TYPES_64_BIT.include?(string) then :x64
        else raise "Don't know if #{instance_type} is i386 or x64"
        end
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
      def keys
        @options[:keys] || self.class.keys
      end
      def monitor
        @options[:monitor] || self.class.monitor
      end
      def elastic_ip
        @options[:ip]
      end
      def instance_id
        ec2.instance_id
      end
      def aws_dns_name
        describe_instance[:dns_name]
      end
      def launch_time
        xml_time = describe_instance[:aws_launch_time]
        logger.debug xml_time
        Time.xmlschema(xml_time)
      end
      def instance_running?
        describe_instance![:aws_state] == 'running'
      end
      def describe_instance!
        @describe_instance = nil
        logger.debug describe_instance
        describe_instance
      end
      def describe_instance
        @describe_instance ||= ec2.describe_instance
      end
    end

    AVAILABILITY_ZONES = %w[
      us-east-1a us-east-1b us-east-1c us-east-1d
      us-west-1a us-west-1b
      eu-west-1a eu-west-1b
      ap-southeast-1a ap-southeast-1b
      ap-northeast-1a ap-northeast-1b
    ]
    INSTANCE_TYPES_32_BIT = %w[m1.small c1.medium t1.micro]
    INSTANCE_TYPES_64_BIT = %w[m1.large m1.xlarge m2.xlarge m2.2xlarge m2.4xlarge c1.xlarge cc1.4xlarge t1.micro]
    INSTANCE_TYPES = (INSTANCE_TYPES_32_BIT + INSTANCE_TYPES_64_BIT).uniq
    SYMBOL_CONSTANT_MAP = (AVAILABILITY_ZONES + INSTANCE_TYPES).inject({}) { |memo,str| memo[str.tr('-.','_').to_sym] = str; memo }

    def constant (symbol)
      SYMBOL_CONSTANT_MAP[symbol]
    end

    def logger
      @logger ||= self.class.logger
    end
    
  end
end

