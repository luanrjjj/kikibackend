require 'digest'

module GenankiApp
  module Util
    def self.guid_for(*fields)
      hash_str = fields.join('__')
      Digest::SHA1.hexdigest(hash_str)[0...16].to_i(16)
    end
  end
end