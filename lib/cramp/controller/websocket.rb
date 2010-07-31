module Cramp
  module Controller
    module WebsocketExtension      
      WEBSOCKET_RECEIVE_CALLBACK = 'websocket.receive_callback'.freeze

      def websocket?
        @env['HTTP_CONNECTION'] == 'Upgrade' && @env['HTTP_UPGRADE'] == 'WebSocket'
      end

      def websocket_handshake
        Websocket::Handshake.call(@env)
      end
    end

    class Websocket < Abstract
      autoload :Handshake, "cramp/controller/websocket/handshake"
      autoload :MessageBuffer, "cramp/controller/websocket/message_buffer"
      
      include PeriodicTimer

      # TODO : Websockets shouldn't need this in an ideal world
      include KeepConnectionAlive

      class_inheritable_accessor :on_data_callbacks, :instance_reader => false
      self.on_data_callbacks = []

      class << self
        def backend=(backend)
          raise "Websocket backend #{backend} is unknown" unless [:thin, :rainbows].include?(backend.to_sym)
          require "cramp/controller/websocket/#{backend}_backend.rb"
        end

        def on_data(*methods)
          self.on_data_callbacks += methods
        end
      end

      def process
        @env["websocket.receive_callback"] = method(:receive_data)
        super
      end

      def render(body)
        body = "\x00#{body}\xff"
        if body.respond_to?(:force_encoding)
          body.force_encoding("UTF-8")
        end
        @body.call(body)
      end

      def receive_data(data)
        @data ||= ""
        @data << data
        
        error = false

        while !error
          pointer = 0
          frame_type = @data[pointer].to_i
          pointer += 1

          if (frame_type & 0x80) == 0x80
            # If the high-order bit of the /frame type/ byte is set
            length = 0

            loop do
              b = @data[pointer].to_i
              return false unless b
              pointer += 1
              b_v = b & 0x7F
              length = length * 128 + b_v
              break unless (b & 0x80) == 0x80
            end

            if @data[pointer+length-1] == nil
              # Incomplete data - leave @data to accumulate
              error = true
            else
              # Straight from spec - I'm sure this isn't crazy...
              # 6. Read /length/ bytes.
              # 7. Discard the read bytes.
              @data = @data[(pointer+length)..-1]

              # If the /frame type/ is 0xFF and the /length/ was 0, then close
              if length == 0
                finish
              else
                error = true
              end
            end
          else
            # If the high-order bit of the /frame type/ byte is _not_ set
            msg = @data.slice!(/^\x00([^\xff]*)\xff/)
            if msg
              msg.gsub!(/\A\x00|\xff\z/, '')
              msg.force_encoding('UTF-8') if msg.respond_to?(:force_encoding)
              receive_message(msg)
            else
              error = true
            end
          end
        end

        false
      end
      
      def receive_message(message)        
        self.class.on_data_callbacks.each do |callback|
          EM.next_tick { send(callback, message) }
        end
      end
    end
  end
end
