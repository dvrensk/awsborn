module Awsborn
  class Keychain
    def initialize (path = nil)
      @keychain = path
    end

    def unlock
      unless @unlocked
        system 'security', 'unlock-keychain', '-p', master_password, @keychain
        @unlocked = true
      end
    end

    def lock
      system 'security', 'lock-keychain', @keychain
      @unlocked = false
    end

    def note (name)
      unlock
      hex_dump = find_generic_password(name)
      text = decode_hex(hex_dump)
      text = string_content(text) if multi_encoded?(text)
      text
    end

    def find_generic_password (name)
      dump = `security -q find-generic-password -s "#{name}" -g "#{@keychain}" 2>&1 1>/dev/null`
      hex_dump = dump[/password: 0x(\S+)/, 1]
      raise "Note '#{name}' not found in #{@keychain}" unless hex_dump
      hex_dump
    end

    def decode_hex (hex_dump)
      text = ""
      0.step(hex_dump.size - 2, 2) { |i| text << hex_dump[i,2].hex.chr }
      text
    end
    
    def multi_encoded? (note)
      note.include?(%q(<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">))
    end

    def string_content (note)
      text = note[%r{<string>(.*)</string>}m,1]
      text.gsub!('&lt;','<')
      text.gsub!('&gt;','>')
      text.gsub!('&amp;','&')
      text
    end
    
    def master_password
      unless @password
        dump = `security -q find-generic-password -s "#{File.basename(@keychain)}" -g 2>&1`
        @password = dump[/password: "(.*)"/, 1]
      end
      @password
    end

  end
end