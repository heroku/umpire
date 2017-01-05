require "scrolls"

module Umpire
  module Log
    def self.log(data, &blk)
      if Config.deploy == "test"
        blk.call if blk
      else
        Scrolls.log({app: Config.app, deploy: Config.deploy}.merge(data), &blk)
      end
    end

    def self.context(data, &blk)
      Scrolls.context(data, &blk)
    end

    def self.add_global_context(data)
      Scrolls.add_global_context(data)
    end
  end
end
