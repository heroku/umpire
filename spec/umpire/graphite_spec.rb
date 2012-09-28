require 'spec_helper'

describe Umpire::Graphite do
  describe "get_values_for_range" do
    let(:graphite_url) { "https://graphite.example.com" }
    let(:metric) { "foo.bar" }
    let(:range) { 60 }
    let(:stub_request_with_values) { stub_request(:get, "#{graphite_url}/render/?format=json&from=-#{range}s&target=#{metric}").to_return(:body => [{"target"=>metric, "datapoints"=>[[4.47, 1348851060]]}].to_json) }
    let(:stub_request_without_values) { stub_request(:get, "#{graphite_url}/render/?format=json&from=-#{range}s&target=#{metric}").to_return(:body => [].to_json) }

    it "should return an Array" do
      stub_request_with_values
      Umpire::Graphite.get_values_for_range(graphite_url, metric, range).should be_kind_of(Array)
    end

    it "should make a call out to graphite" do
      stub_request_with_values
      Umpire::Graphite.get_values_for_range(graphite_url, metric, range)
      stub_request_with_values.should have_been_requested.once
    end

    it "should return the expected values" do
      stub_request_with_values
      Umpire::Graphite.get_values_for_range(graphite_url, metric, range).should eq([4.47])
    end

    it "should raise an exception if graphite returns empty data" do
      stub_request_without_values
      lambda { Umpire::Graphite.get_values_for_range(graphite_url, metric, range) }.should raise_error(MetricNotFound)
    end

    it "should raise an exception if the graphite HTTP request fails for any reason" do
      stub_request(:get, "#{graphite_url}/render/?format=json&from=-#{range}s&target=#{metric}").to_timeout
      lambda { Umpire::Graphite.get_values_for_range(graphite_url, metric, range) }.should raise_error(MetricServiceRequestFailed)
    end
  end
end
