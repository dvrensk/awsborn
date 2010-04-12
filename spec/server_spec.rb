require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class SampleServer < Awsborn::Server
  instance_type :m1_small
  image_id 'ami-2fc2e95b'
  keys :all
end

describe Awsborn::Server do
  before(:each) do
    @server = SampleServer.new :sample, :zone => :eu_west_1a, :disk => {:sdf => "vol-aaaaaaaa"}
  end
  context "first of all" do
    it "should have a connection to the EU service point"
    
  end
  
  context "#launch when not started" do
    before(:each) do
      @server.stub(:running?).and_return(false)
    end
    
  end
end
