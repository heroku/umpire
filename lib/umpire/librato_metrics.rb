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

    def compose_values_for_range(function, metrics, range, sum_sources)
      raise MetricNotComposite, "too few metrics" if metrics.nil? || metrics.size < 2
      raise MetricNotComposite, "too many metrics" if metrics.size > 2

      composite = CompositeMetric.for(function)
      values = metrics.map { |m| get_values_for_range(m, range, sum_sources) }
      composite.new(*values).value
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

module CompositeMetric
  def self.for(function)
    case function
    when "sum"
      Sum
    when "divide"
      Division
    when "multiply"
      Multiplication
    else
      raise MetricNotComposite, "invalid compose function: #{function}"
    end
  end

  class Sum
    attr_reader :value

    def initialize(*values)
      first = values.shift
      @value = first.zip(*values).map do |items|
        items.inject(0) { |sum, i| sum += i }
      end
    end
  end

  class Division
    attr_reader :value

    def initialize(*values)
      @value = values[0].zip(values[1]).map do |v1, v2|
        v1.to_f / v2 unless v2.nil? || v2 == 0
      end.compact
    end
  end

  class Multiplication
    attr_reader :value

    def initialize(*values)
      @value = values[0].zip(values[1]).map do |v1, v2|
        v1 * v2 unless v2.nil?
      end.compact
    end
  end

end

