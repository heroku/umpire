module Umpire
  module Graphite
    extend self

    def get_values_for_range(graphite_url, metric, range)
      #RestClient.get("#{Config.graphite_url}/render/?target=#{metric}&format=json&from=-#{range}s")
      json = RestClient.get("#{graphite_url}/render/?target=#{metric}&format=json&from=-#{range}s")
      JSON.parse(json)
    end
  end
end
