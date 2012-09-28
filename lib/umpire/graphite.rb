module Umpire
  module Graphite
    extend self

    def get_values_for_range(graphite_url, metric, range)
      json = RestClient.get("#{graphite_url}/render/?target=#{metric}&format=json&from=-#{range}s")
      data = JSON.parse(json)

      data.empty? ? [] : data.first["datapoints"].map { |v, _| v }.compact
    end
  end
end
