require "umpire/config"
require "scrolls"

module Umpire
  module Log
    def self.log(data, &blk)
      if Config.deploy == "test"
        blk.call if blk
      else
        Scrolls.log({app: "umpire", deploy: Config.deploy}.merge(data), &blk)
      end
    end
  end
end
