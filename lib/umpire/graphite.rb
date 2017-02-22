require 'uri'
require 'base64'

module Umpire
  module Graphite
    extend self

    def get_values_for_range(graphite_url, metric, range)
      begin
        json = Excon.get(url(graphite_url, metric, range), :headers => headers, :expects => [200]).body
        data = JSON.parse(json)
        data.empty? ? raise(MetricNotFound) : data.flat_map { |metric| metric["datapoints"] }.map(&:first).compact
      rescue Excon::Errors::Error => e
        raise MetricServiceRequestFailed, e.message
      end
    end

    def url(graphite_url, metric, range)
      URI.encode(URI.decode("#{graphite_url}/render/?target=#{metric}&format=json&from=-#{range}s"))
    end

    def headers
      username = Umpire::Config.basic_auth_username
      password = Umpire::Config.basic_auth_password

      return {} unless (username && password)
      auth_string = Base64.strict_encode64("#{username}:#{password}")
      {
        'Authorization' => "Basic #{auth_string}"
      }
    end
  end
end
