require 'spec_helper'

describe Umpire::LibratoMetrics do

  let(:client_double) do
    client = double('client')
    Umpire::LibratoMetrics.stub(:client) { client_double }
    client
  end

  describe "get_values_for_range" do

    it "calls the Librato client as expected" do
      client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { {"all" => []} }
      Umpire::LibratoMetrics.get_values_for_range('foo', 60)
    end

    it "returns values as expected" do
      data = { "all" => [ {"value" => 1}, {"value" => 10}, {"value" => 365} ] }
      client_double.should_receive(:fetch) { data }
      Umpire::LibratoMetrics.get_values_for_range('foo', 60).should eq([1, 10, 365])
    end

    it "handles empty data approprately" do
      client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { {} }
      Umpire::LibratoMetrics.get_values_for_range('foo', 60).should eq([])
    end

    it "uses sum_means data when asked" do
      data = { "all" => [
        {"value" => 1, "sum_means" => 10},
        {"value" => 2, "sum_means" => 20},
        {"value" => 365, "sum_means" => 3650}
      ] }
      client_double.should_receive(:fetch) { data }
      Umpire::LibratoMetrics.get_values_for_range('foo', 60, {from: :sum_means}).should eq([10, 20, 3650])
    end

    describe "with colons" do
      it "uses sum_means data when asked" do
        data = { "all" => [
          {"value" => 1, "sum_means" => 10},
          {"value" => 2, "sum_means" => 20},
          {"value" => 365, "sum_means" => 3650}
        ] }
        client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources:false, start_time: Time.now.to_i - 60) { data }
        Umpire::LibratoMetrics.get_values_for_range('foo:sum_means', 60).should eq([10, 20, 3650])
      end

      it "specifies a group_by when asked" do
        data = { "all" => [
          {"value" => 1, "sum_means" => 10},
          {"value" => 2, "sum_means" => 20},
          {"value" => 365, "sum_means" => 3650}
        ] }
        client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources:false, start_time: Time.now.to_i - 60, group_by: 'sum') { data }
        Umpire::LibratoMetrics.get_values_for_range('foo:sum_means:sum', 60).should eq([10, 20, 3650])
      end
    end

    it "uses the source when passed" do
      client_double.should_receive(:fetch).with('foo', {summarize_sources: true, breakout_sources: false, source: "bar", start_time: Time.now.to_i - 60}) { {} }
      Umpire::LibratoMetrics.get_values_for_range('foo', 60, {source: 'bar'}).should eq([])
    end
  end

  describe "composite values" do
    it "raises error with an invalid compose function" do
      expect do
        Umpire::LibratoMetrics.compose_values_for_range("invalid", ["foo", "bar"], 60)
      end.to raise_error(MetricNotComposite)
    end

    it "composes two metrics at most" do
      # more can be supported later as required
      expect do
        Umpire::LibratoMetrics.compose_values_for_range("invalid", ["foo", "bar", "foobar"], 60)
      end.to raise_error(MetricNotComposite)
    end

    %w'divide multiply'.each do |function|
      it "expects at least two metrics for #{function}" do
        expect do
          Umpire::LibratoMetrics.compose_values_for_range(function, ["foo.bar"], 60)
        end.to raise_error(MetricNotComposite)
      end
    end

    it "supports the sum function" do
      data1 = { "all" => [ {"value" => 1}, {"value" => 10}, {"value" => 30} ] }
      data2 = { "all" => [ {"value" => 2}, {"value" => 20}, {"value" => 40} ] }
      data3 = { "all" => [ {"value" => 3}, {"value" => 30}, {"value" => 50} ] }
      client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data1 }
      client_double.should_receive(:fetch).with('bar', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data2 }
      client_double.should_receive(:fetch).with('buzz', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data3 }
      Umpire::LibratoMetrics.compose_values_for_range("sum", ["foo", "bar","buzz"], 60).
        should eq([6, 60, 120])
    end

    it "supports the sum function with empty values" do
      data1 = { "all" => [ {"value" => 1}, {"value" => 10}, {"value" => 30} ] }
      data2 = { "all" => [ ] }
      client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data1 }
      client_double.should_receive(:fetch).with('bar', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data2 }
      Umpire::LibratoMetrics.compose_values_for_range("sum", ["foo", "bar"], 60).
        should eq([1, 10, 30])
    end

    it "supports sum_means sources" do
      data1 = { "all" => [ {"value" => 1, "sum_means" => 3}, {"value" => 10, "sum_means" => 20} ] }
      data2 = { "all" => [ {"value" => 2, "sum_means" => 5}, {"value" => 20, "sum_means" => 30} ] }
      client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data1 }
      client_double.should_receive(:fetch).with('bar', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data2 }
      Umpire::LibratoMetrics.compose_values_for_range("sum", ["foo", "bar"], 60, {from: :sum_means}).
        should eq([8, 50])
    end

    it "supports the divide function" do
      data1 = { "all" => [ {"value" => 1}, {"value" => 10}, {"value" => 30} ] }
      data2 = { "all" => [ {"value" => 2}, {"value" => 15}, {"value" => 40} ] }
      client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data1 }
      client_double.should_receive(:fetch).with('bar', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data2 }
      Umpire::LibratoMetrics.compose_values_for_range("divide", ["foo", "bar"], 60).
        should eq([0.5, 10.0 / 15, 30.0 / 40])
    end

    describe "unbalanced divisions" do
      it "ignores zero denominators" do
        data1 = { "all" => [ {"value" => 1}, {"value" => 5}, {"value" => 30} ] }
        data2 = { "all" => [ {"value" => 2}, {"value" => 0}, {"value" => 15} ] }
        client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data1 }
        client_double.should_receive(:fetch).with('bar', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data2 }
        Umpire::LibratoMetrics.compose_values_for_range("divide", ["foo", "bar"], 60).
          should eq([0.5, 30.0 / 15])
      end

      it "supports ignores extra numerators" do
        data1 = { "all" => [ {"value" => 1}, {"value" => 10}, {"value" => 30} ] }
        data2 = { "all" => [ {"value" => 2}, {"value" => 15} ] }
        client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data1 }
        client_double.should_receive(:fetch).with('bar', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data2 }
        Umpire::LibratoMetrics.compose_values_for_range("divide", ["foo", "bar"], 60).
          should eq([0.5, 10.0 / 15])
      end

      it "supports ignores extra denominators" do
        data1 = { "all" => [ {"value" => 1}, {"value" => 10} ] }
        data2 = { "all" => [ {"value" => 2}, {"value" => 15}, {"value" => 30} ] }
        client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data1 }
        client_double.should_receive(:fetch).with('bar', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data2 }
        Umpire::LibratoMetrics.compose_values_for_range("divide", ["foo", "bar"], 60).
          should eq([0.5, 10.0 / 15])
      end
    end

    it "supports the multiply function" do
      data1 = { "all" => [ {"value" => 1}, {"value" => 10}, {"value" => 30.2} ] }
      data2 = { "all" => [ {"value" => 2}, {"value" => 15}, {"value" => 40.3} ] }
      client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data1 }
      client_double.should_receive(:fetch).with('bar', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data2 }
      Umpire::LibratoMetrics.compose_values_for_range("multiply", ["foo", "bar"], 60).
        should eq([2, 150, 30.2 * 40.3])
    end

    describe "unbalanced multiplications" do
      it "ignores extra terms in the first values list" do
        data1 = { "all" => [ {"value" => 1}, {"value" => 10}, {"value" => 30} ] }
        data2 = { "all" => [ {"value" => 2}, {"value" => 15} ] }
        client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data1 }
        client_double.should_receive(:fetch).with('bar', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data2 }
        Umpire::LibratoMetrics.compose_values_for_range("multiply", ["foo", "bar"], 60).
          should eq([2, 10.0 * 15])
      end

      it "ignores extra terms in the second values list" do
        data1 = { "all" => [ {"value" => 1}, {"value" => 10} ] }
        data2 = { "all" => [ {"value" => 2}, {"value" => 15}, {"value" => 30} ] }
        client_double.should_receive(:fetch).with('foo', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data1 }
        client_double.should_receive(:fetch).with('bar', summarize_sources: true, breakout_sources: false, start_time: Time.now.to_i - 60) { data2 }
        Umpire::LibratoMetrics.compose_values_for_range("multiply", ["foo", "bar"], 60).
          should eq([2, 10.0 * 15])
      end
    end

  end

end

