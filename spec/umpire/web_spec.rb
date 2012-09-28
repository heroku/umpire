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
          get '/check'
          last_response.status.should eq(401)
        end
      end

      context "with basic auth" do
        before(:each) do
          authorize "test", "test"
        end
        
        it "should return a 400 if params are not passed" do
          get '/check'
          last_response.status.should eq(400)
        end
      end
    end
  end
end
