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

    it "handles empty data approprately" do
      client_double.should_receive(:fetch).with('foo', :start_time => Time.now.to_i - 60, :summarize_sources => true) { {} }
      Umpire::LibratoMetrics.get_values_for_range('foo', 60).should eq([])
    end

    it "uses summarized data when asked" do
      data = { "all" => [
        {"value" => 1, "summarized" => 10},
        {"value" => 2, "summarized" => 20},
        {"value" => 365, "summarized" => 3650}
      ] }
      client_double.should_receive(:fetch) { data }
      Umpire::LibratoMetrics.get_values_for_range('foo', 60, true).should eq([10, 20, 3650])
    end
  end
end
