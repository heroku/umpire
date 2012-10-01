require 'spec_helper'

describe Umpire::LibratoMetrics do
  describe "get_values_for_range" do
    let(:client_double) do
      client = double('client')
      Umpire::LibratoMetrics.stub(:client) { client_double }
      client
    end
    it "calls the Librato client as expected" do
      client_double.should_receive(:fetch).with('foo', :start_time => Time.now.to_i - 60, :summarize_sources => true) { {"all" => []} }
      Umpire::LibratoMetrics.get_values_for_range('foo', 60)
    end

    it "returns values as expected" do
      data = { "all" => [ {"value" => 1}, {"value" => 10}, {"value" => 365} ] }
      client_double.should_receive(:fetch) { data }
      Umpire::LibratoMetrics.get_values_for_range('foo', 60).should eq([1, 10, 365])
    end
  end
end
