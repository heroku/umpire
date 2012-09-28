require 'spec_helper'

describe Umpire::Graphite do
  describe "get_values_for_range" do
    let(:graphite_url) { "https://graphite.example.com" }
    let(:metric) { "foo.bar" }
    let(:range) { 60 }

    before(:each) do
      @stub = stub_request(:get, "#{graphite_url}/render/?format=json&from=-#{range}s&target=#{metric}").to_return(:body => [].to_json)
    end

    it "should return an Array" do
      Umpire::Graphite.get_values_for_range(graphite_url, metric, range).should be_kind_of(Array)
    end

    it "should make a call out to graphite" do
      Umpire::Graphite.get_values_for_range(graphite_url, metric, range)
      @stub.should have_been_requested.once
    end
  end
end
