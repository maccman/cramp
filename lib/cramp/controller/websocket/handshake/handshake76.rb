require 'digest/md5'

module Cramp
  module Controller
    class Websocket
      class Handshake76 < Handshake        
        def call
          challenge_response = solve_challange(
            @env['HTTP_SEC_WEBSOCKET_KEY1'],
            @env['HTTP_SEC_WEBSOCKET_KEY2'],
            @env['rack.input'].read
          )

          location  = "ws://#{@env['HTTP_HOST']}#{@env['REQUEST_PATH']}"

          upgrade =  "HTTP/1.1 101 WebSocket Protocol Handshake\r\n"
          upgrade << "Upgrade: WebSocket\r\n"
          upgrade << "Connection: Upgrade\r\n"
          upgrade << "Sec-WebSocket-Location: #{location}\r\n"
          upgrade << "Sec-WebSocket-Origin: #{@env['HTTP_ORIGIN']}\r\n"
          if protocol = @env['HTTP_SEC-WEBSOCKET-PROTOCOL']
            validate_protocol!(protocol)
            upgrade << "Sec-WebSocket-Protocol: #{protocol}\r\n"
          end
          upgrade << "\r\n"
          upgrade << challenge_response

          upgrade
        end

        private
          def solve_challange(first, second, third)
            # Refer to 5.2 4-9 of the draft 76
            sum = [(extract_nums(first) / count_spaces(first))].pack("N*") +
              [(extract_nums(second) / count_spaces(second))].pack("N*") +
              third
            Digest::MD5.digest(sum)
          end

          def extract_nums(string)
            string.scan(/[0-9]/).join.to_i
          end

          def count_spaces(string)
            spaces = string.scan(/ /).size
            # As per 5.2.5, abort the connection if spaces are zero.
            raise HandshakeError, "Websocket Key1 or Key2 does not contain spaces - this is a symptom of a cross-protocol attack" if spaces == 0
            spaces
          end

          def validate_protocol!(protocol)
            raise HandshakeError, "Invalid WebSocket-Protocol: empty" if protocol.empty?
            # TODO: Validate characters
          end
      end
    end
  end
end