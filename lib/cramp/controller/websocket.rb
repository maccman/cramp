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
        @env['websocket.receive_callback'] = method(:_on_data_receive)
        super
      end

      def render(body)
        @body.call("\x00#{body}\xff")
      end

      def _on_data_receive(data)
        data = data.split(/\000([^\377]*)\377/).select{|d| !d.empty? }.collect{|d| d.gsub(/^\x00|\xff$/, '') }
        self.class.on_data_callbacks.each do |callback|
          data.each do |message|
            EM.next_tick { send(callback, message) }
          end
        end
      end
      
    end
  end
end
