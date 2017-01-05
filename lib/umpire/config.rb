ENV["TZ"] = "UTC"

require 'pry'
require 'excon'
if ENV["SSL_VERIFY_PEER"]  == "false"
  Excon.defaults[:ssl_verify_peer] = false
end

module Umpire
  module Config

    def self.env!(k)
      ENV[k] || raise("missing key #{k}")
    end

    def self.deploy; env!("DEPLOY"); end
    def self.graphite_url; env!("GRAPHITE_URL"); end
    def self.force_https?; env!("FORCE_HTTPS") == "true"; end
    def self.api_key; env!("API_KEY"); end
    def self.librato_email; env!("LIBRATO_EMAIL"); end
    def self.librato_key; env!("LIBRATO_KEY"); end

    def self.app
      ENV["APP"] || "umpire"
    end

    def self.debug?
      !!ENV["DEBUG"]
    end

    def self.find_scope_by_key(value)
      env = ENV.find { |k, v| k =~ /\AAPI_KEY/ && v == value }
      return if env.nil?

      matches = env[0].match(/\A(?:API_KEY?)(_[A-Z]+)?(_DEPRECATED)?\z/)
      name    = matches.captures.compact

      if name.empty? || name[0].include?("DEPRECATED")
        name.unshift("global")
      end

      return name.join.downcase.sub(/\A_/, "")
    end
  end
end
