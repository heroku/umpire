require "spec_helper"

describe Umpire::Web do
  include Rack::Test::Methods

  def app
    Umpire::Web
  end

  describe "GET /check" do
    let(:request_id) { "r12345" }
    let(:request_headers) { {"HTTP_X_REQUEST_ID" => request_id} }

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
        get "/check", {}, request_headers

        last_response.status.should eq(400)
        last_response.body.should eq({"error" => "metric is required, range is required, one of min or max are required", "request_id" => request_id}.to_json + "\n")
      end

      it "should call Graphite.get_values_for_range" do
        mock_graphite_url = "https://graphite.example.com"
        Umpire::Config.stub(:graphite_url) { mock_graphite_url }
        Umpire::Graphite.should_receive(:get_values_for_range).with(mock_graphite_url, "foo.bar", 60) { [] }
        get "/check?metric=foo.bar&range=60&max=100"
      end

      it "should return a 404 if there are no data points" do
        Umpire::Graphite.stub(:get_values_for_range) { [] }
        get "/check?metric=foo.bar&range=60&max=100"
        last_response.status.should eq(404)
      end

      it "should return a 200 if there are no data points and empty_ok is passed" do
        Umpire::Graphite.stub(:get_values_for_range) { [] }
        get "/check?metric=foo.bar&range=60&max=100&empty_ok=true", {}, request_headers
        last_response.status.should eq(200)
        last_response.body.should eq({"error" => "no values for metric in range", "request_id" => request_id}.to_json + "\n")
      end

      it "should return a 400 if an invalid value for empty_ok is passed" do
        Umpire::Graphite.stub(:get_values_for_range) { [] }
        get "/check?metric=foo.bar&range=60&max=100&empty_ok=no", {}, request_headers
        last_response.status.should eq(400)
        last_response.body.should eq({"error" => "empty_ok must be one of yes/y/1/true", "request_id" => request_id}.to_json + "\n")
      end

      it "should return data if there is data" do
        Umpire::Graphite.stub(:get_values_for_range) { [1] }
        get "/check?metric=foo.bar&range=60&max=100&empty_ok=true", {}, request_headers
        last_response.body.should eq({"value" => 1.0, "min" => nil, "max" => 100.0, "num_points" => 1, "request_id" => request_id}.to_json + "\n")
      end

      it "should return an average value of the metric if passed 'aggregate' param set to 'avg'" do
        Umpire::Graphite.stub(:get_values_for_range) { [1, 2, 3, 4, 5] }
        get "/check?metric=foo.bar&range=60&max=100&aggregate=avg", {}, request_headers
        last_response.body.should eq({"value" => 3.0, "min" => nil, "max" => 100.0, "num_points" => 5, "request_id" => request_id}.to_json + "\n")
      end

      it "should return a sum of the values of the metric if passed 'aggregate' param set to 'sum'" do
        Umpire::Graphite.stub(:get_values_for_range) { [1, 2, 3, 4, 5] }
        get "/check?metric=foo.bar&range=60&max=100&aggregate=sum", {}, request_headers
        last_response.body.should eq({"value" => 15.0, "min" => nil, "max" => 100.0, "num_points" => 5, "request_id" => request_id}.to_json + "\n")
      end

      it "should return a min value of the metric if passed 'aggregate' param set to 'min'" do
        Umpire::Graphite.stub(:get_values_for_range) { [1, 2, 3, 4, 5] }
        get "/check?metric=foo.bar&range=60&max=100&aggregate=min", {}, request_headers
        last_response.body.should eq({"value" => 1.0, "min" => nil, "max" => 100.0, "num_points" => 5, "request_id" => request_id}.to_json + "\n")
      end

      it "should return a max value of the metric if passed 'aggregate' param set to 'max'" do
        Umpire::Graphite.stub(:get_values_for_range) { [1, 2, 3, 4, 5] }
        get "/check?metric=foo.bar&range=60&max=100&aggregate=max", {}, request_headers
        last_response.body.should eq({"value" => 5.0, "min" => nil, "max" => 100.0, "num_points" => 5, "request_id" => request_id}.to_json + "\n")
      end

      it "should return a 500 if the data is out of range" do
        Umpire::Graphite.stub(:get_values_for_range) { [1] }
        get "/check?metric=foo.bar&range=60&min=100", {}, request_headers
        last_response.status.should eq(500)
        last_response.body.should eq({"value" => 1.0, "min" => 100.0, "max" => nil, "num_points" => 1, "request_id" => request_id}.to_json + "\n")
      end

      it "should return a 503 if graphite is unavailable" do
        message = "it broke"
        Umpire::Graphite.stub(:get_values_for_range) { raise MetricServiceRequestFailed, message }
        get "/check?metric=foo.bar&range=60&min=100", {}, request_headers
        last_response.status.should eq(503)
        last_response.body.should eq({"error" => "connecting to backend metrics service failed with error '#{message}'", "request_id" => request_id}.to_json + "\n")
      end

      it "should return a 200 if the data is within range" do
        Umpire::Graphite.stub(:get_values_for_range) { [1] }
        get "/check?metric=foo.bar&range=60&min=1", {}, request_headers
        last_response.should be_ok
        last_response.body.should eq({"value" => 1.0, "min" => 1.0, "max" => nil, "num_points" => 1, "request_id" => request_id}.to_json + "\n")
      end

      describe "with librato" do
        it "should call LibratoMetrics if passed the backend param set to librato" do
          Umpire::Graphite.should_not_receive(:get_values_for_range)
          Umpire::LibratoMetrics.should_receive(:get_values_for_range).with("foo.bar", 60, {}) { [] }
          get "/check?metric=foo.bar&range=60&max=100&backend=librato"
        end

        it "should call LibratoMetrics with a from=sum_means from if passed via a param" do
          Umpire::Graphite.should_not_receive(:get_values_for_range)
          Umpire::LibratoMetrics.should_receive(:get_values_for_range).with("foo.bar", 60, {from: "sum_means"}) { [20] }
          get "/check?metric=foo.bar&range=60&min=10&backend=librato&from=sum_means"
          last_response.should be_ok
        end

        it "should call LibratoMetrics with a source=blah from if passed via a param" do
          Umpire::Graphite.should_not_receive(:get_values_for_range)
          Umpire::LibratoMetrics.should_receive(:get_values_for_range).with("foo.bar", 60, {source: "blah"}) { [20] }
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
            Umpire::LibratoMetrics.should_receive(:compose_values_for_range)
              .with("divide", ["foo.bar"], 60, {}) { raise MetricNotComposite }
            get "/check?metric=foo.bar&range=60&min=10&backend=librato&compose=divide"
            last_response.status.should eq(400)
          end

          it "should accept subtract as a compose function" do
            Umpire::LibratoMetrics.should_receive(:compose_values_for_range)
              .with("subtract", ["foo.bar", "bar.foo"], 60, {}) { [10] }
            get "/check?metric=foo.bar,bar.foo&range=60&min=10&backend=librato&compose=subtract"
            last_response.should be_ok
          end

          it "should accept sum as a compose function" do
            Umpire::LibratoMetrics.should_receive(:compose_values_for_range)
              .with("sum", ["foo.bar", "bar.foo", "foo.baz"], 60, {}) { [10] }
            get "/check?metric=foo.bar,bar.foo,foo.baz&range=60&min=10&backend=librato&compose=sum"
            last_response.should be_ok
          end

          it "should accept divide as a compose function" do
            Umpire::LibratoMetrics.should_receive(:compose_values_for_range)
              .with("divide", ["foo.bar", "bar.foo"], 60, {}) { [10] }
            get "/check?metric=foo.bar,bar.foo&range=60&min=10&backend=librato&compose=divide"
            last_response.should be_ok
          end

          it "should accept multiply as a compose function" do
            Umpire::LibratoMetrics.should_receive(:compose_values_for_range)
              .with("multiply", ["foo.bar", "bar.foo"], 60, {}) { [10] }
            get "/check?metric=foo.bar,bar.foo&range=60&min=10&backend=librato&compose=multiply"
            last_response.should be_ok
          end

          it "should support summarized sources for all metrics" do
            Umpire::LibratoMetrics.should_receive(:compose_values_for_range)
              .with("sum", ["foo.bar", "bar.foo"], 60, {from: "sum_means"}) { [10] }
            get "/check?metric=foo.bar,bar.foo&range=60&min=10&backend=librato&compose=sum&from=sum_means"
            last_response.should be_ok
          end

          it "should return a 503 if librato is unavailable" do
            message = "it broke"
            Umpire::LibratoMetrics.should_receive(:get_values_for_range) { raise MetricServiceRequestFailed, message }
            get "/check?metric=foo.bar&range=60&min=100&backend=librato", {}, request_headers
            last_response.status.should eq(503)
            last_response.body.should eq({"error" => "connecting to backend metrics service failed with error '#{message}'", "request_id" => request_id}.to_json + "\n")
          end
        end
      end
    end
  end
end
