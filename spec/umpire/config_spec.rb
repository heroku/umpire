require "spec_helper"

describe Umpire::Config do
  describe ".find_scope_by_key" do
    subject { Umpire::Config.find_scope_by_key password }

    context "when using the global api key" do
      let(:password) { "test" }
      it { should eq "global" }
    end

    context "when using the deprecated global api key" do
      let(:password) { "deprecated" }
      it { should eq "global_deprecated" }
    end

    context "when using a scoped api key" do
      let(:password) { "test-2" }
      it { should eq "pingdom" }
    end

    context "when using a deprecated scoped api key" do
      let(:password) { "deprecated-2" }
      it { should eq "pingdom_deprecated" }
    end

    context "when using an invalid api key" do
      let(:password) { "invalid" }
      it { should be_nil }
    end
  end
end
