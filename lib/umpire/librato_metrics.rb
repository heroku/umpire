module Umpire
  module LibratoMetrics
    extend self

    def get_values_for_range(metric, range, sum_sources=false)
      # value == avg
      value_key = sum_sources ? "summarized" : "value"
      begin
        start_time = Time.now.to_i - range
        results = client.fetch(metric, :start_time => start_time, :summarize_sources => true)
        results.has_key?('all') ? results["all"].map { |h| h[value_key] } : []
      rescue Librato::Metrics::NotFound
        raise MetricNotFound
      rescue Librato::Metrics::NetworkError
        raise MetricServiceRequestFailed
      end
    end

    def client
      unless @client
        @client = ::Librato::Metrics::Client.new
        @client.authenticate Config.librato_email, Config.librato_key
      end
      @client
    end
  end
end
