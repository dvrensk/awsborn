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

  describe "aws_constant" do
    it "should look up an availability zone" do
      @server.aws_constant(:eu_west_1a).should == "eu-west-1a"
    end
    it "should look up an instance type" do
      @server.aws_constant(:m1_large).should == "m1.large"
    end
    it "should raise an error if the symbol is unknown" do
      expect{@server.aws_constant(:unknown_constant)}.to raise_error(Awsborn::UnknownConstantError)
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

  describe "running?" do
    it "first tries to set instance_id using find_instance_id_by_name" do
      @server.stub!(:find_instance_id_by_name).and_return("i-1234")
      @server.stub!(:find_instance_id_by_volume).and_return(nil)
      @server.ec2.should_receive(:instance_id=).with("i-1234")
      @server.running?
    end
    it "defaults back to using find_instance_by_volume" do
      @server.stub!(:find_instance_id_by_name).and_return(nil)
      @server.stub!(:find_instance_id_by_volume).and_return("i-2345")
      @server.ec2.should_receive(:instance_id=).with("i-2345")
      @server.running?
    end
    it "returns the value that instance_id was set to" do
      @server.stub!(:find_instance_id_by_name).and_return("i-1234")
      @server.stub!(:find_instance_id_by_volume).and_return(nil)
      @server.running?.should == "i-1234"
    end
    it "raises a ServerError if find_instance_id_by_name and find_instance_id_by_volume doesn't match" do
      @server.stub!(:find_instance_id_by_name).and_return("i-1234")
      @server.stub!(:find_instance_id_by_volume).and_return("i-2345")
      expect {@server.running?}.to raise_error(Awsborn::ServerError)
    end
  end

  describe "#find_instance_id_by_volume" do
    it "returns the instance id of the (hopefully unique) instance to which all defined disks are attached" do
      @server.stub!(:disk_volume_ids).and_return(["volume_id_1", "volume_id_2"])
      @server.ec2.stub!(:instance_id_for_volume).and_return("i-123")
      @server.find_instance_id_by_volume.should == "i-123"
    end

    it "returns nil if no instance was found" do
      @server.stub!(:disk_volume_ids).and_return([])
      @server.find_instance_id_by_volume.should be_nil
    end

    it "raises a ServerError if multiple instances were found" do
      @server.stub!(:disk_volume_ids).and_return(["volume_id_1", "volume_id_2"])
      @server.ec2.stub!(:instance_id_for_volume).and_return do |vol_id|
        {"volume_id_1" => "i-1",
         "volume_id_2" => "i-2"}[vol_id]
      end
      expect {@server.find_instance_id_by_volume}.to raise_error(Awsborn::ServerError)
    end
  end

  describe "#find_instance_id_by_name" do
    before do
      @connection = mock("connection")
      @server.stub!(:full_name).and_return "fyllenamn"
      @server.ec2.stub!(:connection).and_return @connection
    end

    it "returns the instance id of the (hopefully unique) pending or running instance with the correct name" do
      instance = {:aws_instance_id => "i-1234"}
      @connection.should_receive(:describe_instances).
          with(:filters => {
                'tag:Name' => "fyllenamn",
                'instance-state-name' => ['pending', 'running']
               }).
          and_return [instance]
      @server.find_instance_id_by_name.should == "i-1234"
    end

    it "returns nil if no instance was found" do
      @connection.stub!(:describe_instances).and_return []
      @server.find_instance_id_by_name.should be_nil
    end

    it "raises an exception if too many instances were found" do
      @connection.stub!(:describe_instances).and_return ["too", "many"]
      expect {@server.find_instance_id_by_name}.to raise_error(Awsborn::ServerError)
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
      ec2.stub!(:set_instance_name)
      ec2.should_receive(:create_security_group_if_missing).exactly(3).times
      @server.stub(:ec2).and_return(ec2)
      @server.should_receive(:instance_running?).and_return(true)
      @server.should_receive(:aws_dns_name).and_return('asdf')
      @server.launch_instance(key_pair)
    end
  end

end
