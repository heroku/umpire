require "webmock/rspec"

require "umpire"

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end

ENV["FORCE_HTTPS"] = "false"
ENV["API_KEY"] = "test"
ENV["DEPLOY"] = "test"
ENV["GRAPHITE_URL"] = "https://graphite.example.com"
