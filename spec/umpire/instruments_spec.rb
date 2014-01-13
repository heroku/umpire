require "spec_helper"

describe Umpire::Instruments do
  context "api" do
    let(:metric) { "foo.bar" }
    let(:range) { 60 }

    let(:graphite_url) { "http://graphite.local" }
    let(:graphite_path) { "/render/" }
    let(:graphite_query) { "format=json&from=-#{range}s&target=#{metric}" }

    it "should log relevant values when calling external apis" do
      stub_request(:get, "#{graphite_url}#{graphite_path}?#{graphite_query}")
        .to_return(:body => [{"target"=>metric, "datapoints"=>[[4.47, 1348851060]]}].to_json)

      Umpire::Instruments::Api.should_receive(:log) do |data, &blk|
        case data[:name]
        when "excon.request"
          data.keys.sort.should eq([:name, :host, :path, :query].sort)
          data[:host].should eq("graphite.local")
          data[:path].should eq(graphite_path)
          data[:query].should match(/target=foo\.bar/)
        when "excon.response"
          data.keys.sort.should eq([:name, :remote_ip, :status].sort)
          data[:status].should eq(200)
        end
        blk.call
      end.at_least(:once)

      Umpire::Graphite.get_values_for_range(graphite_url, metric, range)
    end

    it "should log errors when external apis fail" do
      stub_request(:get, "#{graphite_url}#{graphite_path}?#{graphite_query}")
        .to_return(:body => {:error => "on noes"}.to_json, :status => 500)

      Umpire::Instruments::Api.should_receive(:log) do |data, &blk|
        case data[:name]
        when "excon.error"
          data.keys.sort.should eq([:name, :error_class, :error_message].sort)
          data[:error_class].should eq("Excon::Errors::InternalServerError")
          data[:error_message].should match(/InternalServerError/)
        end
        blk.call
      end.at_least(:once)

      expect { Umpire::Graphite.get_values_for_range(graphite_url, metric, range) }.to raise_error(MetricServiceRequestFailed)
    end
  end
end
