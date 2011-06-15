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
    Awsborn.verbose = false
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

  context ".security_group" do
    class SecureServer < Awsborn::Server
      instance_type :m1_small
      image_id 'ami-2fc2e95b'
      security_group 'Common', 'Other'
      individual_security_group true
    end

    before do
      @server = SecureServer.new :sample, :zone => :eu_west_1a, :disk => {:sdf => "vol-aaaaaaaa"}
    end
    it "allows multiple security groups" do
      key_pair = mock(:key_pair)
      key_pair.should_receive(:name).and_return('fake')
      ec2 = mock(:ec2)
      ec2.should_receive(:instance_id).and_return('i-asdf')
      ec2.should_receive(:launch_instance).with do |image_id, options|
        image_id.should == 'ami-2fc2e95b'
        options[:group_ids].should == ['Common', 'Other', 'SecureServer sample']
      end
      ec2.should_receive(:create_security_group_if_missing).exactly(3).times
      @server.stub(:ec2).and_return(ec2)
      @server.should_receive(:instance_running?).and_return(true)
      @server.should_receive(:aws_dns_name).and_return('asdf')
      @server.launch_instance(key_pair)
    end
  end

end
