ENV["TZ"] = "UTC"

module Umpire
  module Config
    def self.env!(k)
      ENV[k] || raise("missing key #{k}")
    end

    def self.deploy; env!("DEPLOY"); end
    def self.graphite_url; env!("GRAPHITE_URL"); end
    def self.port; env!("PORT"); end
    def self.force_https?; env!("FORCE_HTTPS") == "true"; end
    def self.api_key; env!("API_KEY"); end
  end
end
