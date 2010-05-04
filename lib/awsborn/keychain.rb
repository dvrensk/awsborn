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

    def get (name)
      unlock
      password_line = find_generic_password(name)
      if password_line.match(/^password: 0x/)
        hex_dump = password_line[/password: 0x(\S+)/, 1]
        text = decode_hex(hex_dump)
        text = string_content(text) if multi_encoded?(text)
      elsif password_line.match(/^password: "/)
        text = password_line[/password: "(.+)"/, 1]
      else
        raise "Note '#{name}' not found in #{@keychain}"
      end
      text
    end

    def find_generic_password (name)
      `security -q find-generic-password -s "#{name}" -g "#{@keychain}" 2>&1 1>/dev/null`
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