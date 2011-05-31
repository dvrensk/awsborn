require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Awsborn::Ec2 do
  context ".endpoint_for_zone" do
    it "should have endpoints for zones in five regions" do
      Awsborn::Ec2.endpoint_for_zone(:eu_west_1a).should == 'https://eu-west-1.ec2.amazonaws.com'
      Awsborn::Ec2.endpoint_for_zone("eu_west_1b").should == 'https://eu-west-1.ec2.amazonaws.com'
      Awsborn::Ec2.endpoint_for_zone(:us_west_1b).should == 'https://us-west-1.ec2.amazonaws.com'
      Awsborn::Ec2.endpoint_for_zone(:us_east_1b).should == 'https://us-east-1.ec2.amazonaws.com'
    end
  end
end
