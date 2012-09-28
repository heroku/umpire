require "umpire/config"
require "scrolls"

module Umpire
  module Log
    def self.merge(data1, data2)
      data1.merge(data2)
    end

    def self.log(data, &blk)
      Scrolls.log(merge({app: "umpire", deploy: Config.deploy}, data), &blk)
    end
  end
end
