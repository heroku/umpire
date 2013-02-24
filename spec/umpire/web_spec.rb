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

        describe "with librato" do
          it "should call LibratoMetrics if passed the backend param set to librato" do
            Graphite.should_not_receive(:get_values_for_range)
            Umpire::LibratoMetrics.should_receive(:get_values_for_range).with('foo.bar', 60, :value, nil) { [] }
            get "/check?metric=foo.bar&range=60&max=100&backend=librato"
          end

          it "should call LibratoMetrics with a from=sum_means from if passed via a param" do
            Graphite.should_not_receive(:get_values_for_range)
            Umpire::LibratoMetrics.should_receive(:get_values_for_range).with('foo.bar', 60, :sum_means, nil) { [20] }
            get "/check?metric=foo.bar&range=60&min=10&backend=librato&from=sum_means"
            last_response.should be_ok
          end

          it "should call LibratoMetrics with a source=blah from if passed via a param" do
            Graphite.should_not_receive(:get_values_for_range)
            Umpire::LibratoMetrics.should_receive(:get_values_for_range).with('foo.bar', 60, :value, 'blah') { [20] }
            get "/check?metric=foo.bar&range=60&min=10&backend=librato&source=blah"
            last_response.should be_ok
          end

          describe "with composite metrics" do
            it "should return 400 if multiple metrics are passed, but without a compose function" do
              Umpire::LibratoMetrics.should_not_receive(:get_values_for_range)
              get "/check?metric=foo.bar,bar.foo&range=60&min=10&backend=librato"
              last_response.status.should eq(400)
            end

            it "should return 400 if a compose function is passed, but metric is not composite" do
              Umpire::LibratoMetrics.should_receive(:compose_values_for_range).
                with("divide", ["foo.bar"], 60, :value, nil) { raise MetricNotComposite }
              get "/check?metric=foo.bar&range=60&min=10&backend=librato&compose=divide"
              last_response.status.should eq(400)
            end

            it "should accept sum as a compose function" do
              Umpire::LibratoMetrics.should_receive(:compose_values_for_range).
                with("sum", ["foo.bar", "bar.foo"], 60, :value, nil) { [10] }
              get "/check?metric=foo.bar,bar.foo&range=60&min=10&backend=librato&compose=sum"
              last_response.should be_ok
            end

            it "should accept divide as a compose function" do
              Umpire::LibratoMetrics.should_receive(:compose_values_for_range).
                with("divide", ["foo.bar", "bar.foo"], 60, :value, nil) { [10] }
              get "/check?metric=foo.bar,bar.foo&range=60&min=10&backend=librato&compose=divide"
              last_response.should be_ok
            end

            it "should accept multiply as a compose function" do
              Umpire::LibratoMetrics.should_receive(:compose_values_for_range).
                with("multiply", ["foo.bar", "bar.foo"], 60, :value, nil) { [10] }
              get "/check?metric=foo.bar,bar.foo&range=60&min=10&backend=librato&compose=multiply"
              last_response.should be_ok
            end

            it "should support summarized sources for all metrics" do
              Umpire::LibratoMetrics.should_receive(:compose_values_for_range).
                with("sum", ["foo.bar", "bar.foo"], 60, :sum_means, nil) { [10] }
              get "/check?metric=foo.bar,bar.foo&range=60&min=10&backend=librato&compose=sum&from=sum_means"
              last_response.should be_ok
            end
          end

        end

      end
    end
  end
end
