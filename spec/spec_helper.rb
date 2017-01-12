require "webmock/rspec"
require "rack/test"

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
  config.mock_with :rspec do |c|
    c.syntax = :should
  end
end

ENV["FORCE_HTTPS"] = "false"
ENV["DEPLOY"] = "test"
ENV["GRAPHITE_URL"] = "https://graphite.example.com"

ENV["API_KEY"] = "test"
ENV["API_KEY_DEPRECATED"] = "deprecated"

ENV["API_KEY_PINGDOM"] = "test-2"
ENV["API_KEY_PINGDOM_DEPRECATED"] = "deprecated-2"

ENV["RACK_ENV"] = "test"

require "umpire"
require "umpire/web"
