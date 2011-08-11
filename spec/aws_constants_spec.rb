require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Awsborn::AwsConstants do
  include Awsborn::AwsConstants
  describe "endpoint_for_zone_and_service" do
    it "should have endpoints for each service and for zones in five regions" do
      endpoint_for_zone_and_service(:eu_west_1a,  :ec2).should == 'https://eu-west-1.ec2.amazonaws.com'
      endpoint_for_zone_and_service("eu_west_1b", :ec2).should == 'https://eu-west-1.ec2.amazonaws.com'
      endpoint_for_zone_and_service(:us_west_1b,  :ec2).should == 'https://us-west-1.ec2.amazonaws.com'
      endpoint_for_zone_and_service(:us_east_1b,  :ec2).should == 'https://us-east-1.ec2.amazonaws.com'
      endpoint_for_zone_and_service(:eu_west_1a,  :elb).should == 'https://eu-west-1.elasticloadbalancing.amazonaws.com'
      endpoint_for_zone_and_service("eu_west_1b", :elb).should == 'https://eu-west-1.elasticloadbalancing.amazonaws.com'
      endpoint_for_zone_and_service(:us_west_1b,  :elb).should == 'https://us-west-1.elasticloadbalancing.amazonaws.com'
      endpoint_for_zone_and_service(:us_east_1b,  :elb).should == 'https://us-east-1.elasticloadbalancing.amazonaws.com'
    end
  end

  describe "zone_to_awz_region" do
    it "accepts a zone symbol and returns its region" do
      zone_to_awz_region(:eu_west_1a).should == 'eu-west-1'
    end
    it "accepts an aws zone symbol and returns its region" do
      zone_to_awz_region('eu-west-1a').should == 'eu-west-1'
    end
    it "raise an error if no region found" do
      expect{zone_to_awz_region('santa-northpole-2b')}.to raise_error(Awsborn::UnknownConstantError)
    end
    it "returns a region even when a region is given" do
      zone_to_awz_region('eu-west-1').should == 'eu-west-1'
      zone_to_awz_region(:eu_west_1).should == 'eu-west-1'
    end
  end

  describe "symbol_to_aws_zone" do
    it "accepts a zone symbol and returns its aws zone" do
      symbol_to_aws_zone(:eu_west_1a).should == 'eu-west-1a'
    end
    it "raise an error if no matching aws zone found" do
      expect{symbol_to_aws_zone(:santa_northpole_2b)}.to raise_error(Awsborn::UnknownConstantError)
    end
  end

  describe "aws_zone_to_symbol" do
    it "returns a symbol from aws zone" do
      aws_zone_to_symbol('eu-west-1a').should == :eu_west_1a
    end
    it "raises an error if the zone is unknown" do
      expect{aws_zone_to_symbol('santa-northpole-2a')}.to raise_error(Awsborn::UnknownConstantError)
    end
  end

  describe "symbol_to_aws_instance_type" do
    it "accepts an instance type  symbol and returns its aws instance type" do
      symbol_to_aws_instance_type(:m1_small).should == 'm1.small'
    end
    it "raise an error if no matching aws zone found" do
      expect{symbol_to_aws_instance_type(:xx_megalarge)}.to raise_error(Awsborn::UnknownConstantError)
    end
  end

  describe "aws_instance_type_to_symbol" do
    it "returns a symbol from aws instance type" do
      aws_instance_type_to_symbol('m1.small').should == :m1_small
    end
    it "raises an error if the instance type is unknown" do
      expect{aws_instance_type_to_symbol('xx.megalarge')}.to raise_error(Awsborn::UnknownConstantError)
    end
  end

  describe "awz_constant" do
    it "should look up an availability zone" do
      awz_constant(:eu_west_1a).should == "eu-west-1a"
    end
    it "should look up an instance type" do
      awz_constant(:m1_large).should == "m1.large"
    end
    it "should raise an error if the symbol is unknown" do
      expect{awz_constant(:unknown_constant)}.to raise_error(Awsborn::UnknownConstantError)
    end
  end

end
