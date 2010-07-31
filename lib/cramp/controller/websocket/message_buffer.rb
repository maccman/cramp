class MessageBuffer < StringIO
  def messages
    rewind
    result = []
    
    loop do
      frame_type = readchar
      
      if (frame_type & 0x80) == 0x80
        length = payload_length
                
        if frame_type == 0xFF and length == 0
          return false
        else
          bytes = read(length)
        
          # Additional data to come
          break if bytes.length != length
          
          trim!
          result << bytes
        end
        
      elsif frame_type == 0x00
        bytes = read_until("\xff")
        
        # Additional data to come
        break unless bytes
        
        trim!
        result << bytes
      else
        raise "Unknown frame type"
      end
    end
    
    result
  end
  
  protected  
    def trim!
      string.replace(read)
    end
  
    def read_until(char)
      result = []
    
      while byte = read(1)
        if byte == char
          return result.join('')
        end
        result << byte
      end
      return
    end
    
    def payload_length
      length = 0
      loop do
        b = readchar
        return unless b
        length = length * 128 + (b & 0x7f)
        break if (b & 0x80) == 0
      end      
      length
    end
end