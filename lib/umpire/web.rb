require "sinatra/base"
require "rack/handler/mongrel"
require "rack-ssl-enforcer"
require "umpire/config"
require "umpire/log"
require "json"
require "uuidtools"
require "instruments"
require "restclient"


module Umpire
  class Web < Sinatra::Base
    enable :dump_errors
    disable :show_exceptions
    use Rack::SslEnforcer if Config.force_https?
    register Sinatra::Instrumentation
    instrument_routes

    before do
      content_type :json
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
        @auth.provided? && @auth.basic? && @auth.credentials && (@auth.credentials[1] == Config.api_key)
      end
    end

    get "/check" do
      protected!
      metric = params["metric"]
      min = (params["min"] && params["min"].to_f)
      max = (params["max"] && params["max"].to_f)
      range = (params["range"] && params["range"].to_i)
      if !(metric && (min || max) && range)
        status 400
        JSON.dump({"error" => "missing parameters"}) + "\n"
      else
        data = JSON.parse(RestClient.get("#{Config.graphite_url}/render/?target=#{metric}&format=json&from=-#{range}s"))
        if (data == [])
          status 404
          JSON.dump({"error" => "metric not found"}) + "\n"
        else
          points = data.first["datapoints"].map { |v, _| v }.compact
          if points.empty?
            status 404
            JSON.dump({"error" => "no values for metric in range"}) + "\n"
          else
            value = (points.reduce { |a,b| a+b }) / points.size.to_f
            if ((min && (value < min)) || (max && (value > max)))
              status 500
            else
              status 200
            end
            JSON.dump({"value" => value}) + "\n"
          end
        end
      end
    end

    get "/health" do
      status 200
      JSON.dump({"health" => "ok"}) + "\n"
    end

    not_found do
      status 404
      JSON.dump({"error" => "not found"}) + "\n"
    end

    error do
      status 500
      JSON.dump({"error" => "internal server error"}) + "\n"
    end

    def self.start
      log(fn: "start", at: "build")
      @server = Mongrel::HttpServer.new("0.0.0.0", Config.port)
      @server.register("/", Rack::Handler::Mongrel.new(Web.new))

      log(fn: "start", at: "install_trap")
      Signal.trap("TERM") do
        log(fn: "trap")
        @server.stop(true)
        log(fn: "trap", at: "exit", status: 0)
        Kernel.exit!(0)
      end

      log(fn: "start", at: run, port: Config.port)
      @server.run.join
    end

    def log(data, &blk)
      Web.log(data, &blk)
    end

    def self.log(data, &blk)
      data.delete(:level)
      Log.log(Log.merge({ns: "web"}, data), &blk)
    end
  end
end

Instruments.defaults = {logger: Umpire::Web, method: :log}
