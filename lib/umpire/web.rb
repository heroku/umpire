require "thin"
require "sinatra/base"
require 'rack/ssl'
require 'rack-timeout'
require "instruments"

module Umpire
  class Web < Sinatra::Base
    enable :dump_errors
    disable :show_exceptions
    register Sinatra::Instrumentation
    instrument_routes

    before do
      content_type :json
      grab_request_id
    end

    after do
      Thread.current[:scope] = nil
      Thread.current[:request_id] = nil
    end

    helpers do
      def log(data, &blk)
        self.class.log(data, &blk)
      end

      def protected!
        unless authorized?
          response["WWW-Authenticate"] = %(Basic realm="Restricted Area")
          throw(:halt, [401, JSON.dump({"error" => "not authorized"}) + "\n"])
        end
      end

      def authorized?
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        if @auth.provided? && @auth.basic? && @auth.credentials
          if Thread.current[:scope] = Config.find_scope_by_key(@auth.credentials[1])
            true
          end
        end
      end

      def grab_request_id
        Thread.current[:request_id] = request.env["HTTP_HEROKU_REQUEST_ID"] || request.env["HTTP_X_REQUEST_ID"]
      end

      def valid?(params)
        params["metric"] && (params["min"] || params["max"]) && params["range"]
      end

      def use_librato_backend?
        params["backend"] == "librato"
      end

      def fetch_points(params)
        metric = params["metric"]
        range = (params["range"] && params["range"].to_i)

        if use_librato_backend?
          compose = params["compose"]

          opts = {}
          %w{source from resolution}.each do |key|
            next unless val = params[key]
            opts[key.to_sym] = val
          end

          if !compose && metric.split(",").size > 1
            raise MetricNotComposite, "multiple metrics without a compose function"
          end

          if compose
            LibratoMetrics.compose_values_for_range(compose, metric.split(","), range, opts)
          else
            LibratoMetrics.get_values_for_range(metric, range, opts)
          end
        else
          Graphite.get_values_for_range(Config.graphite_url, metric, range)
        end

      end

      def create_aggregator(aggregation_method)
        case aggregation_method
        when "avg"
          Aggregator::Avg.new
        when "sum"
          Aggregator::Sum.new
        when "min"
          Aggregator::Min.new
        when "max"
          Aggregator::Max.new
        else
          Aggregator::Avg.new
        end
      end
    end

    get "/check" do
      protected!

      unless valid?(params)
        log(action: "check", at: "invalid_params")
        halt 400, JSON.dump({"error" => "missing parameters"}) + "\n"
      end

      min = (params["min"] && params["min"].to_f)
      max = (params["max"] && params["max"].to_f)
      empty_ok = params["empty_ok"]
      aggregator = create_aggregator(params["aggregate"])

      begin
        points = fetch_points(params)
        if points.empty?
          log(action: "check", metric: params["metric"], source: params["source"], at: "no_points")
          status empty_ok ? 200 : 404
          JSON.dump({"error" => "no values for metric in range"}) + "\n"
        else
          value = aggregator.aggregate(points)
          if ((min && (value < min)) || (max && (value > max)))
            log(action: "check", at: "out_of_range", metric: params["metric"], source: params["source"], min: min, max: max, value: value, num_points: points.count)
            status 500
          else
            log(action: "check", at: "ok", metric: params["metric"], source: params["source"], min: min, max: max, value: value, num_points: points.count)
            status 200
          end
          JSON.dump({"value" => value, "min" => min, "max" => max, "num_points" => points.count}) + "\n"
        end
      rescue MetricNotComposite => e
        log(action: "check", at: "metric_not_composite", metric: params["metric"], source: params["source"], error: e.message)
        halt 400, JSON.dump("error" => e.message) + "\n"
      rescue MetricNotFound
        log(action: "check", at: "metric_not_found", source: params["source"], metric: params["metric"])
        halt 404, JSON.dump({"error" => "metric not found"}) + "\n"
      rescue MetricServiceRequestFailed => e
        log(action: "check", at: "metric_service_request_failed", metric: params["metric"], source: params["source"], message: e.message)
        halt 503, JSON.dump({"error" => "connecting to backend metrics service failed with error 'request timed out'"}) + "\n"
      end
    end

    get "/health" do
      log(at: "health")
      JSON.dump({"health" => "ok"}) + "\n"
    end

    get "/*" do
      log(at: "not_found")
      halt 404, JSON.dump({"error" => "not found"}) + "\n"
    end

    error do
      e = env["sinatra.error"]
      log(at: "internal_error", "class" => e.class, message: e.message)
      status 500
      JSON.dump({"error" => "internal server error"}) + "\n"
    end

    def self.start
      log(fn: "start", at: "build")
      @server = Thin::Server.new("0.0.0.0", Config.port) do

        if Config.force_https?
          use Rack::SSL
        end

        use Rack::Timeout
        Rack::Timeout.timeout = 29

        run Web.new
      end

      log(fn: "start", at: "install_trap")
      Signal.trap("TERM") do
        log(fn: "trap")
        @server.stop!
        log(fn: "trap", at: "exit", status: 0)
        Kernel.exit!(0)
      end

      @server.start

      log(fn: "start", at: run, port: Config.port)
    end

    def self.log(data, &blk)
      data.delete(:level)
      Log.log({ns: "web", scope: Thread.current[:scope], request_id: Thread.current[:request_id]}.merge(data), &blk)
    end
  end
end

Instruments.defaults = {logger: Umpire::Web, method: :log}
