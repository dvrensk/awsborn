require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class SampleServer < Awsborn::Server
  instance_type :m1_small
  image_id 'ami-2fc2e95b'
  keys :all
end

class BigAndSmallServer < Awsborn::Server
  instance_type :m1_small
  image_id :x64 => 'ami-big', :i386 => 'ami-small'
end

describe Awsborn::Server do
  before(:each) do
    @server = SampleServer.new :sample, :zone => :eu_west_1a, :disk => {:sdf => "vol-aaaaaaaa"}
  end

  context "constants" do
    it "should look up an availability zone" do
      @server.constant(:eu_west_1a).should == "eu-west-1a"
    end
    it "should look up an instance type" do
      @server.constant(:m1_large).should == "m1.large"
    end
  end

  describe "image_id" do
    it "should use a given string" do
      @server.image_id.should == 'ami-2fc2e95b'
    end
    it "should use the i386 image for a small server" do
      server = BigAndSmallServer.new :sample, :zone => :eu_west_1a, :disk => {:sdf => "vol-a"}, :instance_type => :m1_small
      server.image_id.should == 'ami-small'
    end
    it "should use the i386 image for a micro server (which could use either)" do
      server = BigAndSmallServer.new :sample, :zone => :eu_west_1a, :disk => {:sdf => "vol-a"}, :instance_type => :t1_micro
      server.image_id.should == 'ami-small'
    end
    it "should use the x64 image for a big server" do
      server = BigAndSmallServer.new :sample, :zone => :eu_west_1a, :disk => {:sdf => "vol-a"}, :instance_type => :m1_large
      server.image_id.should == 'ami-big'
    end
  end

  # TODO
  # context "first of all" do
  #   it "should have a connection to the EU service point"
  # end
  
  context "#launch when not started" do
    before(:each) do
      @server.stub(:running?).and_return(false)
    end
    
  end
end
