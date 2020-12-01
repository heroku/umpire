require "umpire/log"

module Umpire
  module Instruments
    class Api
      class << self
        def instrument(name, params = {}, &blk)
          lparams = {name: name}
          case name
          when "excon.retry", "excon.request"
            lparams.merge!(host: params[:host], path: params[:path], query: params[:query])
          when "excon.response"
            lparams[:status] = params[:status]
            lparams[:remote_ip] = params[:remote_ip]
            lparams[:server] = params[:headers]["Server"] if params[:headers]["Server"]
          when "excon.error"
            lparams[:error_class] = params[:error].class.to_s
            lparams[:error_message] = params[:error].message
          end

          log(lparams) do
            yield if blk
          end
        end

        def log(data, &blk)
          Umpire::Log.log({ns: "instruments-api"}.merge(data), &blk)
        end
      end
    end
  end
end

Excon.defaults[:instrumentor] = Umpire::Instruments::Api
