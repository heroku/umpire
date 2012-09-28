require 'spec_helper'

describe Umpire::Graphite do
  describe "get_values_for_range" do
    let(:graphite_url) { "https://graphite.example.com" }
    let(:range) { 60 }

    it "should return an Array" do
      Umpire::Graphite.get_values_for_range(graphite_url, range).should be_kind_of(Array)
    end
  end
end
