module Umpire
  module LibratoMetrics
    extend self

    # Since we use summarize_sources => true ...
    # :value       == mean of means
    # :count       == mean of count
    # :min         == mean of min
    # :max         == mean of max
    # :sum         == mean of sum
    # :sum_squares == mean of sum_squares
    # :sum_means   == sum of means (aka values)
    # :summarized  == count of sources summarized
    DEFAULT_FROM = :value

    def start_time(range)
      Time.now.to_i - range
    end

    def default_options
      {
        summarize_sources: true,
        breakout_sources: false
      }
    end

    def determine_from(metric, options)
      if options.has_key?(:from)
        options.delete(:from)
      elsif metric.include?(":")
        from = metric.split(":")[1]
        from == "mean" ? "value" : from
      else
        DEFAULT_FROM
      end.to_s
    end

    def determine_group_by(metric)
      parts = metric.split(":")
      if parts.length == 3
        parts[2]
      else
        nil
      end
    end

    def get_values_for_range(metric, range, options={})
      options = default_options.merge(options)

      from = determine_from(metric, options)

      options.merge!(start_time: start_time(range))

      if group_by = determine_group_by(metric)
        options.merge!(group_by: group_by)
      end

      metric = metric.split(":").first

      if Config.debug?
        Log.log(options.merge(range: range, metric: metric))
      end

      results = client.get_measurements(metric, options)

      if Config.debug?
        Log.log({debug: "librato results"}.merge(results))
      end

      # This is the response you get if you try to request
      # a handmade composite metric.
      if all = results.kind_of?(Array) && results.size > 0 && results[0]['series']
        all.map { |h| h[from] }
      elsif all = results.kind_of?(Hash) && results['all']
        all.map { |h| h[from] }
      else
        []
      end
    rescue Librato::Metrics::NotFound
      raise MetricNotFound
    rescue Librato::Metrics::NetworkError => e
      raise MetricServiceRequestFailed, e.message
    end

    def compose_values_for_range(function, metrics, range, options={})
      metric_limit = function == "sum" ? 4 : 2

      raise MetricNotComposite, "too few metrics" if metrics.nil? || metrics.size < 2
      raise MetricNotComposite, "too many metrics" if metrics.size > metric_limit

      composite = CompositeMetric.for(function)
      values = metrics.map { |m| get_values_for_range(m, range, options) }
      composite.new(*values).value
    end

    def client
      unless @client
        @client = ::Librato::Metrics::Client.new
        @client.authenticate Config.librato_email, Config.librato_key
        @client.agent_identifier("umpire", Config.deploy, Config.librato_email)
        @client.faraday_adapter = :excon
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
    when "subtract"
      Subtract
    else
      raise MetricNotComposite, "invalid compose function: #{function}"
    end
  end

  class Sum
    attr_reader :value

    def initialize(*values)
      first = values.shift
      @value = first.zip(*values).map do |items|
        items.inject(0) { |sum, i| sum += i.to_f }
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

  class Subtract
    attr_reader :value

    def initialize(*values)
      @value = values[0].zip(values[1]).map do |items|
        items.inject { |diff, i| diff -= i.to_f }
      end
    end
  end
end

