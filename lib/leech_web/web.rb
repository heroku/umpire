require "sinatra/base"
require "rack/handler/mongrel"
require "omniauth"
require "openid_redis_store"
require "leech_web/config"
require "leech_web/log"
require "json"
require "uuidtools"
require "redis"

module LeechWeb
  class WebLog
    def initialize(app)
      @app = app
    end

    def call(req)
      Web.log(fn: "call", method: req["REQUEST_METHOD"].downcase, path: req["PATH_INFO"]) do
        res = @app.call(req)
      end
    end
  end

  class WebHttps
    def initialize(app)
      @app = app
    end

    def call(req)
      if (Config.force_https? && (req["HTTP_X_FORWARDED_PROTO"] != "https"))
        [302, {"Location" => "https://#{req["HTTP_HOST"]}#{req["PATH_INFO"]}"}, []]
      else
        @app.call(req)
      end
    end
  end

  class Web < Sinatra::Base
    set :logging, false
    set :static, true
    set :root, Config.root

    use WebLog
    use WebHttps
    use Rack::Session::Cookie, :secret => Config.session_secret, :expire_after => (60 * 60 * 24 * 7)

    redis_uri = URI.parse(Config.redis_url)
    redis = Redis.new(:host => redis_uri.host, :port => redis_uri.port, :password => redis_uri.password)
    use OmniAuth::Strategies::GoogleApps, OpenID::Store::Redis.new(redis), :name => "google", :domain => "heroku.com"

    post "/auth/google/callback" do
      session["authorized"] = true
      redirect("/")
    end

    get "/" do
      authorize!
      @leech_search_id = UUIDTools::UUID.random_create.to_s
      erb :index
    end

    get "/search" do
      authorize!
      events_key = "searches.#{params[:search_id]}.events"
      search_data = {"search_id" => params[:search_id], "events_key" => events_key, "query" => params[:query]}
      search_str = JSON.dump(search_data)
      t = (Time.now.to_f * 1000).to_i
      result = log(fn: "hit_redis") do
        redis.multi do
          redis.zadd("searches", t, search_str)
          redis.lrange(events_key, 0, 100000)
          redis.ltrim(events_key, 100000, -1)
        end
      end
      events = result[1]
      headers("Content-Type" => "application/json")
      "[#{events.join(", ")}]"
    end

    get "/health" do
      headers("Content-Type" => "application/json")
      JSON.dump({"status" => "ok"})
    end

    def authorize!
      redirect("/auth/google") if !session["authorized"]
    end

    def unauthorized!
      log(fn: "unauthorized!")
      headers("WWW-Authenticate" => "Basic realm=\"private\"")
      throw :halt, [401, "Authorization Required"]
    end

    def bad_request!
      log(fn: "bad_request!")
      throw :halt, [400, "Bad Request"]
    end

    not_found do
      status 404
      "Not Found"
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
      Log.log(Log.merge({ns: "web"}, data), &blk)
    end
  end
end
