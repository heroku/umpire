require 'spec_helper'

describe Umpire::LibratoMetrics do
  describe "get_values_for_range" do
    it "calls the Librato client as expected" do
      client_double = double('client')
      Umpire::LibratoMetrics.stub(:client) { client_double }

      client_double.should_receive(:fetch).with('foo', :start_time => Time.now.to_i - 60, :summarize_sources => true) { {"all" => []} }
      Umpire::LibratoMetrics.get_values_for_range('foo', 60)
    end
  end
end
