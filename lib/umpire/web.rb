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
    end

    after do
      Thread.current[:scope] = nil
    end

    helpers do
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

          if source = params["source"]
            opts.merge!(source: source)
          end

          if from = params["from"]
            opts.merge!(from: from)
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
    end

    get "/check" do
      protected!

      unless valid?(params)
        status 400
        next JSON.dump({"error" => "missing parameters"}) + "\n"
      end

      min = (params["min"] && params["min"].to_f)
      max = (params["max"] && params["max"].to_f)
      empty_ok = params["empty_ok"]

      begin
        points = fetch_points(params)
        if points.empty?
          status empty_ok ? 200 : 404
          JSON.dump({"error" => "no values for metric in range"}) + "\n"
        else
          value = (points.reduce(&:+)
          value = value / points.size.to_f unless params["average"] == "false"
          if ((min && (value < min)) || (max && (value > max)))
            status 500
          else
            status 200
          end
          JSON.dump({"value" => value}) + "\n"
        end
      rescue MetricNotComposite => e
        status 400
        JSON.dump("error" => e.message) + "\n"
      rescue MetricNotFound
        status 404
        JSON.dump({"error" => "metric not found"}) + "\n"
      rescue MetricServiceRequestFailed
        status 503
        JSON.dump({"error" => "connecting to backend metrics service failed with error 'request timed out'"}) + "\n"
      end
    end

    get "/health" do
      status 200
      JSON.dump({"health" => "ok"}) + "\n"
    end

   get "/*" do
     status 404
     JSON.dump({"error" => "not found"}) + "\n"
   end

    error do
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
      Log.log({ns: "web", scope: Thread.current[:scope]}.merge(data), &blk)
    end
  end
end

Instruments.defaults = {logger: Umpire::Web, method: :log}
