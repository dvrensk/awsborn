module Awsborn
  class SecurityError < StandardError ; end
  class ServerError < StandardError ; end

  class << self
    attr_writer :access_key_id, :secret_access_key, :logger
    attr_accessor :verbose

    Awsborn.verbose = true

    def access_key_id
      @access_key_id ||= ENV['AMAZON_ACCESS_KEY_ID'] 
    end
    
    def secret_access_key
      @secret_access_key ||= ENV['AMAZON_SECRET_ACCESS_KEY']
    end
  
    def logger
      unless defined? @logger
        dir = [File.dirname(File.expand_path($0)), '/tmp'].find { |d| File.writable?(d) }
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
    
  end
end
