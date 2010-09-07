module Awsborn
  class SecurityError < StandardError ; end
  class ServerError < StandardError ; end

  class << self
    attr_writer :access_key_id, :secret_access_key, :logger, :remote_chef_path, :chef_log_level
    attr_accessor :verbose

    Awsborn.verbose = true

    def access_key_id
      @access_key_id ||= ENV['AMAZON_ACCESS_KEY_ID'] 
    end
    
    def secret_access_key
      unless @secret_access_key
        @secret_access_key = ENV['AMAZON_SECRET_ACCESS_KEY']
        if @secret_access_key.to_s == ''
          @secret_access_key = secret_access_key_from_keychain(access_key_id)
        end
      end
      @secret_access_key
    end

    def secret_access_key_from_keychain (key_id)
      @credentials ||= {}
      unless @credentials[key_id]
        dump = `security -q find-generic-password -a "#{key_id}" -g 2>&1`
        secret_key = dump[/password: "(.*)"/, 1]
        @credentials[key_id] = secret_key
      end
      @credentials[key_id]
    end

    def secret_access_key_from_keychain! (key_id)
      secret = secret_access_key_from_keychain key_id
      raise "Could not find secret access key for #{key_id}" if secret.to_s == ''
      secret
    end
    
    def remote_chef_path
      @remote_chef_path ||= '/etc/chef'
    end
  
    def logger
      unless defined? @logger
        dir = [Dir.pwd, '/tmp'].find { |d| File.writable?(d) }
        if dir
          file = File.open(File.join(dir, 'awsborn.log'), 'a')
          file.sync = true
        end
        @logger = Logger.new(file || $stdout)
        @logger.level = Logger::INFO
      end
      @logger
    end
  
    # @throws Interrupt
    def wait_for (message, sleep_seconds = 5, max_wait_seconds = nil)
      stdout_sync = $stdout.sync
      $stdout.sync = true

      start_at = Time.now
      print "Waiting for #{message}.." if Awsborn.verbose
      result = yield
      while ! result
        if max_wait_seconds && Time.now > start_at + max_wait_seconds
          raise Interrupt, "Timed out after #{Time.now - start_at} seconds."
        end
        print "." if Awsborn.verbose
        sleep sleep_seconds
        result = yield
      end
      verbose_output "OK!"
      result
    ensure
      $stdout.sync = stdout_sync
    end
  
    def verbose_output(message)
      puts message if Awsborn.verbose
    end

    def chef_log_level
      @chef_log_level || :info
    end

  end
end
