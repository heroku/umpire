ENV['RACK_ENV'] = 'test'

require "spec_helper"
require "rack/test"

require "umpire/web"

module Umpire
  describe Umpire::Web do
    include Rack::Test::Methods

    def app
      Umpire::Web
    end

    describe "GET /check" do
      context "without basic auth" do
        it "should require basic auth" do
          get "/check"
          last_response.status.should eq(401)
        end
      end

      context "with basic auth" do
        before(:each) do
          authorize "test", "test"
        end
        
        it "should return a 400 if params are not passed" do
          get "/check"
          last_response.status.should eq(400)
        end

        it "should call Graphite.get_values_for_range" do
          mock_graphite_url = "https://graphite.example.com"
          Umpire::Config.stub(:graphite_url) { mock_graphite_url }
          Umpire::Graphite.should_receive(:get_values_for_range).with(mock_graphite_url, "foo.bar", 60) { [] }
          get "/check?metric=foo.bar&range=60&max=100"
        end

        it "should return a 404 if there are no data points" do
          Graphite.stub(:get_values_for_range) { [] }
          get "/check?metric=foo.bar&range=60&max=100"
          last_response.status.should eq(404)
        end

        it "should return a 200 if there are no data points and empty_ok is passed" do
          Graphite.stub(:get_values_for_range) { [] }
          get "/check?metric=foo.bar&range=60&max=100&empty_ok=true"
          last_response.status.should eq(200)
        end
      end
    end
  end
end
