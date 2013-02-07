require "webmock/rspec"

require "umpire"

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end

ENV["FORCE_HTTPS"] = "false"
ENV["DEPLOY"] = "test"
ENV["GRAPHITE_URL"] = "https://graphite.example.com"

ENV["API_KEY"] = "test"
ENV["API_KEY_DEPRECATED"] = "deprecated"

ENV["API_KEY_PINGDOM"] = "test-2"
ENV["API_KEY_PINGDOM_DEPRECATED"] = "deprecated-2"
