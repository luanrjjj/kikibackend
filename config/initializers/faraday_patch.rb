# Monkey-patch Faraday 2.0 to restore basic_auth method for older gems like 'clickhouse'
module Faraday
  class Connection
    def basic_auth(login, pass)
      request :authorization, :basic, login, pass
    end
  end
end

# Increase timeout for Clickhouse gem
if defined?(Clickhouse)
  module Clickhouse
    class Connection
      module Client
        def client
          @client ||= Faraday.new(:url => url) do |f|
            f.options[:timeout] = 300 # 5 minutes
            f.options[:open_timeout] = 60
            f.adapter Faraday.default_adapter
          end
        end
      end
    end
  end
end
