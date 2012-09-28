module Umpire
  module Graphite
    extend self

    def get_values_for_range(graphite_url, metric, range)
      begin
        json = RestClient.get("#{graphite_url}/render/?target=#{metric}&format=json&from=-#{range}s")
        data = JSON.parse(json)
        data.empty? ? raise(MetricNotFound) : data.first["datapoints"].map { |v, _| v }.compact
      rescue RestClient::RequestFailed
        raise MetricServiceRequestFailed
      end
    end
  end
end
