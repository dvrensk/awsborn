require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Awsborn::Ec2 do
  before do
    @ec2 = Awsborn::Ec2.new :eu_west_1
  end

  describe "#set_instance_name" do
    it "sets the name tag of the instance (if launched)" do
      @ec2.stub!(:instance_id).and_return("i-123")
      connection = mock("connection")
      @ec2.stub!(:connection).and_return(connection)

      connection.should_receive(:create_tags).with("i-123", {"Name" => "foo"})
      @ec2.set_instance_name "foo"
    end
    it "raises an exception if the instance hasn't been launched" do
      @ec2.stub!(:instance_id).and_return nil
      expect {@ec2.set_instance_name "foo"}.to raise_error()
    end
  end
end
