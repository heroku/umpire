require "scrolls"

module Umpire
  module Log
    BASE_DATA = {app: Config.app, deploy: Config.deploy}.freeze

    def self.log(data, &blk)
      if Config.deploy == "test"
        blk.call if blk
      else
        Scrolls.log(BASE_DATA.merge(data), &blk)
      end
    end

    def self.log_exception(ex, data = {})
      Scrolls.log_exception(BASE_DATA.merge(data), ex)
    end

    def self.context(data, &blk)
      Scrolls.context(data, &blk)
    end

    def self.add_global_context(data)
      Scrolls.add_global_context(data)
    end
  end
end
