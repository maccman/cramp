module Cramp
  module Controller
    class Websocket
      autoload :Handshake75, "cramp/controller/websocket/handshake/handshake75"
      autoload :Handshake76, "cramp/controller/websocket/handshake/handshake76"

      class Handshake
        class HandshakeError < RuntimeError; end
        
        def self.call(env)
          self.new(env).call
        end
        
        def initialize(env)
          @env = env
        end
        
        def call
          handler.call(@env)
        end
        
        private
          def handler
            case version?
            when 75
              Handshake75
            when 76
              Handshake76
            end
          end
        
          def version?
            @env['HTTP_SEC_WEBSOCKET_KEY1'] ? 76 : 75
          end
      end
    end
  end
end