require 'spec_helper'

describe Umpire::LibratoMetrics do

  let(:client_double) do
    client = double('client')
    Umpire::LibratoMetrics.stub(:client) { client_double }
    client
  end

  describe "get_values_for_range" do

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

  describe "composite values" do
    it "raises error with an invalid compose function" do
      expect do
        Umpire::LibratoMetrics.compose_values_for_range("invalid", ["foo", "bar"], 60, false)
      end.to raise_error(MetricNotComposite)
    end

    it "composes two metrics at most" do
      # more can be supported later as required
      expect do
        Umpire::LibratoMetrics.compose_values_for_range("invalid", ["foo", "bar", "foobar"], 60, false)
      end.to raise_error(MetricNotComposite)
    end

    it "expects at least two metrics" do
      expect do
        Umpire::LibratoMetrics.compose_values_for_range("divide", ["foo.bar"], 60, false)
      end.to raise_error(MetricNotComposite)
    end

    it "supports the sum function" do
      data1 = { "all" => [ {"value" => 1}, {"value" => 10}, {"value" => 30} ] }
      data2 = { "all" => [ {"value" => 2}, {"value" => 20}, {"value" => 40} ] }
      client_double.should_receive(:fetch).with('foo', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data1 }
      client_double.should_receive(:fetch).with('bar', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data2 }
      Umpire::LibratoMetrics.compose_values_for_range("sum", ["foo", "bar"], 60, false).
        should eq([3, 30, 70])
    end

    it "supports summarized sources" do
      data1 = { "all" => [ {"value" => 1, "summarized" => 3}, {"value" => 10, "summarized" => 20} ] }
      data2 = { "all" => [ {"value" => 2, "summarized" => 5}, {"value" => 20, "summarized" => 30} ] }
      client_double.should_receive(:fetch).with('foo', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data1 }
      client_double.should_receive(:fetch).with('bar', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data2 }
      Umpire::LibratoMetrics.compose_values_for_range("sum", ["foo", "bar"], 60, true).
        should eq([8, 50])
    end

    it "supports the divide function" do
      data1 = { "all" => [ {"value" => 1}, {"value" => 10}, {"value" => 30} ] }
      data2 = { "all" => [ {"value" => 2}, {"value" => 15}, {"value" => 40} ] }
      client_double.should_receive(:fetch).with('foo', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data1 }
      client_double.should_receive(:fetch).with('bar', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data2 }
      Umpire::LibratoMetrics.compose_values_for_range("divide", ["foo", "bar"], 60, false).
        should eq([0.5, 10.0 / 15, 30.0 / 40])
    end

    describe "unbalanced divisions" do
      it "ignores zero denominators" do
        data1 = { "all" => [ {"value" => 1}, {"value" => 5}, {"value" => 30} ] }
        data2 = { "all" => [ {"value" => 2}, {"value" => 0}, {"value" => 15} ] }
        client_double.should_receive(:fetch).with('foo', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data1 }
        client_double.should_receive(:fetch).with('bar', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data2 }
        Umpire::LibratoMetrics.compose_values_for_range("divide", ["foo", "bar"], 60, false).
          should eq([0.5, 30.0 / 15])
      end

      it "supports ignores extra numerators" do
        data1 = { "all" => [ {"value" => 1}, {"value" => 10}, {"value" => 30} ] }
        data2 = { "all" => [ {"value" => 2}, {"value" => 15} ] }
        client_double.should_receive(:fetch).with('foo', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data1 }
        client_double.should_receive(:fetch).with('bar', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data2 }
        Umpire::LibratoMetrics.compose_values_for_range("divide", ["foo", "bar"], 60, false).
          should eq([0.5, 10.0 / 15])
      end

      it "supports ignores extra denominators" do
        data1 = { "all" => [ {"value" => 1}, {"value" => 10} ] }
        data2 = { "all" => [ {"value" => 2}, {"value" => 15}, {"value" => 30} ] }
        client_double.should_receive(:fetch).with('foo', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data1 }
        client_double.should_receive(:fetch).with('bar', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data2 }
        Umpire::LibratoMetrics.compose_values_for_range("divide", ["foo", "bar"], 60, false).
          should eq([0.5, 10.0 / 15])
      end
    end

    it "supports the multiply function" do
      data1 = { "all" => [ {"value" => 1}, {"value" => 10}, {"value" => 30.2} ] }
      data2 = { "all" => [ {"value" => 2}, {"value" => 15}, {"value" => 40.3} ] }
      client_double.should_receive(:fetch).with('foo', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data1 }
      client_double.should_receive(:fetch).with('bar', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data2 }
      Umpire::LibratoMetrics.compose_values_for_range("multiply", ["foo", "bar"], 60, false).
        should eq([2, 150, 30.2 * 40.3])
    end

    describe "unbalanced multiplications" do
      it "ignores extra terms in the first values list" do
        data1 = { "all" => [ {"value" => 1}, {"value" => 10}, {"value" => 30} ] }
        data2 = { "all" => [ {"value" => 2}, {"value" => 15} ] }
        client_double.should_receive(:fetch).with('foo', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data1 }
        client_double.should_receive(:fetch).with('bar', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data2 }
        Umpire::LibratoMetrics.compose_values_for_range("multiply", ["foo", "bar"], 60, false).
          should eq([2, 10.0 * 15])
      end

      it "ignores extra terms in the second values list" do
        data1 = { "all" => [ {"value" => 1}, {"value" => 10} ] }
        data2 = { "all" => [ {"value" => 2}, {"value" => 15}, {"value" => 30} ] }
        client_double.should_receive(:fetch).with('foo', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data1 }
        client_double.should_receive(:fetch).with('bar', :start_time => Time.now.to_i - 60, :summarize_sources => true) { data2 }
        Umpire::LibratoMetrics.compose_values_for_range("multiply", ["foo", "bar"], 60, false).
          should eq([2, 10.0 * 15])
      end
    end

  end

end

