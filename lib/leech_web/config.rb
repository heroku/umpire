ENV["TZ"] = "UTC"

module LeechWeb
  module Config
    def self.env!(key)
      ENV[key] || raise("missing #{key}")
    end

    def self.deploy; env!("DEPLOY"); end
    def self.redis_url; env!("REDIS_URL"); end
    def self.session_secret; env!("SESSION_SECRET"); end
    def self.port; env!("PORT"); end
    def self.force_https?; env!("FORCE_HTTPS") == "true"; end

    def self.api_password
      URI.parse(api_url).password
    end

    def self.root
      File.join(File.dirname(__FILE__), "../..")
    end
  end
end
