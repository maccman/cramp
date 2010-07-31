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
        @buffer ||= MessageBuffer.new
        @buffer << data
        messages = @buffer.messages
        
        unless messages
          finish
          return
        end
        
        messages.each do |msg|
          receive_message(msg)
        end
      end
      
      def receive_message(message)
        if message.respond_to?(:force_encoding)
          message.force_encoding("UTF-8")
        end
        
        self.class.on_data_callbacks.each do |callback|
          EM.next_tick { send(callback, message) }
        end
      end
    end
  end
end
