module Umpire
  module LibratoMetrics
    extend self

    def get_values_for_range(metric, range)
      begin
        start_time = Time.now.to_i - range
        results = client.fetch(metric, :start_time => start_time, :summarize_sources => true)
        results["all"].map { |h| h["value"] }
      rescue Librato::Metrics::NotFound
        raise MetricNotFound
      #rescue Exception
      #  raise MetricServiceRequestFailed
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
