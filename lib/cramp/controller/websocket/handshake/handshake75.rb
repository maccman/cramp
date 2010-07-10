module Cramp
  module Controller
    class Websocket
      class Handshake75 < Handshake
        def call
          location = "ws://#{@env['HTTP_HOST']}#{@env['REQUEST_PATH']}"

          upgrade =  "HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
          upgrade << "Upgrade: WebSocket\r\n"
          upgrade << "Connection: Upgrade\r\n"
          upgrade << "WebSocket-Origin: #{@env['HTTP_ORIGIN']}\r\n"
          upgrade << "WebSocket-Location: #{location}\r\n\r\n"

          upgrade
        end
      end
    end
  end
end