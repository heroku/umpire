require "uri"

module Umpire
  module Graphite
    extend self

    def get_values_for_range(graphite_url, metric, range)
      json = Excon.get(url(graphite_url, metric, range), expects: [200]).body
      data = JSON.parse(json)
      data.empty? ? raise(MetricNotFound) : data.flat_map { |metric| metric["datapoints"] }.map(&:first).compact
    rescue Excon::Errors::Error => e
      raise MetricServiceRequestFailed, e.message
    end

    # rubocop: disable Lint/UriEscapeUnescape
    def url(graphite_url, metric, range)
      URI.escape(URI.unescape("#{graphite_url}/render/?target=#{metric}&format=json&from=-#{range}s"))
    end
    # rubocop: enable Lint/UriEscapeUnescape
  end
end
