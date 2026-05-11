# Monkey-patch Faraday 2.0 to restore basic_auth method for older gems
module Faraday
  class Connection
    def basic_auth(login, pass)
      request :authorization, :basic, login, pass
    end
  end
end
