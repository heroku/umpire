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

        it "should return data if there is data" do
          Graphite.stub(:get_values_for_range) { [1] }
          get "/check?metric=foo.bar&range=60&max=100&empty_ok=true"
          last_response.body.should eq({'value' => 1.0}.to_json + "\n")
        end

        it "should return an average value of the metric if passed 'aggregate' param set to 'avg'" do
          Graphite.stub(:get_values_for_range) { [1,2,3,4,5] }
          get "/check?metric=foo.bar&range=60&max=100&aggregate=avg"
          last_response.body.should eq({'value' => 3.0}.to_json + "\n")
        end

        it "should return a sum of the values of the metric if passed 'aggregate' param set to 'sum'" do
          Graphite.stub(:get_values_for_range) { [1,2,3,4,5] }
          get "/check?metric=foo.bar&range=60&max=100&aggregate=sum"
          last_response.body.should eq({'value' => 15.0}.to_json + "\n")
        end

        it "should return a min value of the metric if passed 'aggregate' param set to 'min'" do
          Graphite.stub(:get_values_for_range) { [1,2,3,4,5] }
          get "/check?metric=foo.bar&range=60&max=100&aggregate=min"
          last_response.body.should eq({'value' => 1.0}.to_json + "\n")
        end

        it "should return a max value of the metric if passed 'aggregate' param set to 'max'" do
          Graphite.stub(:get_values_for_range) { [1,2,3,4,5] }
          get "/check?metric=foo.bar&range=60&max=100&aggregate=max"
          last_response.body.should eq({'value' => 5.0}.to_json + "\n")
        end

        it "should return a 500 if the data is out of range" do
          Graphite.stub(:get_values_for_range) { [1] }
          get "/check?metric=foo.bar&range=60&min=100"
          last_response.status.should eq(500)
        end
        
        it "should return a 200 if the data is within range" do
          Graphite.stub(:get_values_for_range) { [1] }
          get "/check?metric=foo.bar&range=60&min=1"
          last_response.should be_ok
        end

        it "should call LibratoMetrics if passed the backend param set to librato" do
          Umpire::LibratoMetrics.should_receive(:get_values_for_range).with('foo.bar', 60) { [] }
          get "/check?metric=foo.bar&range=60&max=100&backend=librato"
        end
      end
    end
  end
end
