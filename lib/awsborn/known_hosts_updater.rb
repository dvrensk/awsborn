module Awsborn
  class KnownHostsUpdater

    class << self
      attr_accessor :logger
      def update_for_server (server)
        known_hosts = new(server.ec2, server.host_name)
        known_hosts.update
      end

      def logger
        @logger ||= Awsborn.logger
      end
    end

    attr_accessor :ec2, :host_name, :host_ip, :console_fingerprint, :fingerprint_file, :logger

    def initialize (ec2, host_name)
      @host_name = host_name
      @ec2 = ec2
    end

    def update
      tries = 0
      begin
        tries += 1
        try_update
      rescue SecurityError => e
        if tries < 8
          logger.debug e.message
          sleep_time = [2**tries, 30].min
          logger.debug "Fingerprint try #{tries} failed, sleeping #{sleep_time} seconds"
          sleep(sleep_time)
          retry
        else
          raise e
        end
      end
    end
    
    def try_update
      get_console_fingerprint
      clean_out_known_hosts
      scan_hosts
      compare_fingerprints!
      save_fingerprints
    end

    def get_console_fingerprint
      # ec2: -----BEGIN SSH HOST KEY FINGERPRINTS-----
      # ec2: 2048 7a:e9:eb:41:b7:45:b1:07:30:ad:13:c5:a9:2a:a1:e5 /etc/ssh/ssh_host_rsa_key.pub (RSA)
      regexp = %r{BEGIN SSH HOST KEY FINGERPRINTS.*((?:[0-9a-f]{2}:){15}[0-9a-f]{2}) /etc/ssh/ssh_host_rsa_key.pub }m
      @console_fingerprint = Awsborn.wait_for "console output", 15, 420 do
        console = ec2.get_console_output
        unless console.empty?
          fingerprint = console[regexp, 1]
          if ! fingerprint
            logger.error "*** SSH RSA fingerprint not found ***"
            logger.error console
            logger.error "*** SSH RSA fingerprint not found ***"
          end
        end
        fingerprint
      end
    end

    def clean_out_known_hosts
      remove_from_known_hosts host_name
      remove_from_known_hosts host_ip
    end
    
    def remove_from_known_hosts (host)
      system "ssh-keygen -R #{host} > /dev/null 2>&1"
    end

    def scan_hosts
      self.fingerprint_file = create_tempfile
      system "ssh-keyscan -t rsa #{host_name} #{host_ip} > #{fingerprint_file} 2>/dev/null"
    end

    def compare_fingerprints!
      name_fingerprint, ip_fingerprint = fingerprints_from_file

      if name_fingerprint.nil? || ip_fingerprint.nil?
        raise SecurityError, "name_fingerprint = #{name_fingerprint.inspect}, ip_fingerprint = #{ip_fingerprint.inspect}"
      elsif name_fingerprint.split[1] != ip_fingerprint.split[1]
        raise SecurityError, "Fingerprints do not match:\n#{name_fingerprint} (#{host_name})\n#{ip_fingerprint} (#{host_ip})!"
      elsif name_fingerprint.split[1] != console_fingerprint
        raise SecurityError, "Fingerprints do not match:\n#{name_fingerprint} (#{host_name})\n#{console_fingerprint} (EC2 Console)!"
      end
    end
    
    def fingerprints_from_file
      `ssh-keygen -l -f #{fingerprint_file}`.split("\n")
    end

    def save_fingerprints
      system "cat #{fingerprint_file} >> #{ENV['HOME']}/.ssh/known_hosts"
    end
    
    def create_tempfile
      tmp = Tempfile.new "awsborn"
      tmp.close
      def tmp.to_s
        path
      end
      tmp
    end
    
    def logger
      @logger ||= self.class.logger
    end

    def host_ip
      @host_ip ||= Resolv.getaddress host_name
    end
  end
end
