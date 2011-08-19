require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Awsborn::Route53 do
  before do
    @mock_interface = mock(:route53_interface)
    RightAws::Route53Interface.stub!(:new).and_return(@mock_interface)
    Awsborn.stub!(:access_key_id).and_return('access_key_id')
    Awsborn.stub!(:secret_access_key).and_return('secret_access_key')
  end

  describe "connection" do
    before do
      @r53 = Awsborn::Route53.new
    end
    it "setup a connection the first time" do
      RightAws::Route53Interface.should_receive(:new).
                             with('access_key_id', 'secret_access_key', :logger => Awsborn.logger).
                             exactly(:once)
      @r53.connection
      @r53.connection
    end
  end

  context "for a valid r53" do
    before do
      @r53 = Awsborn::Route53.new(:eu_west_1b)
    end
  
    describe "zone_exists?" do
      before do
        sample_from_docs = [{:aws_id=>"/hostedzone/Z1K6NCF0EB26FB",
          :caller_reference=>"1295424990-710392-gqMuw-KcY8F-LFlrB-SQhp9",
          :config=>{:comment=>"My test site!"},
          :name=>"my-awesome-site.com."}]
        @mock_interface.stub!(:list_hosted_zones).and_return(sample_from_docs)
      end
      it "checks the result from Route53Interface" do
        @r53.zone_exists?('my-awesome-site.com.').should == true
        @r53.zone_exists?('my-awesome-site.com').should == true
        @r53.zone_exists?('horrible.com').should == false
      end
    end

    describe "create_zone" do
      it "delegates to Route53Interface" do
        @mock_interface.should_receive(:create_hosted_zone).with({:name => 'example.net.', :config => {:comment => ''}})
        @r53.create_zone 'example.net'
      end
    end

    describe "alias_target" do
      it "delegates cleverly to Route53Interface" do
        zones = [{:aws_id=>"/hostedzone/Z111111111111",
          :config=>{:comment=>"My test site!"},
          :name=>"example.net."}]
        @mock_interface.should_receive(:list_hosted_zones).and_return(zones)
        alias_target = { :hosted_zone_id => 'Z2222222222', :dns_name => 'example-1111111111.us-east-1.elb.amazonaws.com.' }
        alias_record = { :name => 'example.net.', :type => 'A', :alias_target => alias_target }
        @mock_interface.should_receive(:list_resource_record_sets).with(/Z111111111111/).and_return([alias_record])

        @r53.alias_target('example.net')
      end
    end

    describe "add_alias_record" do
      it "delegates to Route53Interface" do
        zones = [{:aws_id=>"/hostedzone/Z111111111111", :name=>"example.net."}]
        @mock_interface.stub!(:list_hosted_zones).and_return(zones)

        alias_target = { :hosted_zone_id => 'Z2222222222', :dns_name => 'example-1111111111.us-east-1.elb.amazonaws.com.' }
        alias_record = { :name => 'example.net.', :type => 'A', :alias_target => alias_target }

        # .dup since it will get :action => :create
        @mock_interface.should_receive(:create_resource_record_sets).with(/Z111111111111/, [alias_record.dup])

        @r53.add_alias_record(:alias => 'example.net.', :lb_fqdn => alias_target[:dns_name], :lb_zone => 'Z2222222222')
      end
    end

    describe "remove_alias_records" do
      it "delegates to Route53Interface" do
        zones = [{:aws_id=>"/hostedzone/Z111111111111", :name=>"example.net."}]
        @mock_interface.stub!(:list_hosted_zones).and_return(zones)

        alias_target = { :hosted_zone_id => 'Z2222222222', :dns_name => 'example-1111111111.us-east-1.elb.amazonaws.com.' }
        alias_record = { :name => 'example.net.', :type => 'A', :alias_target => alias_target }
        @mock_interface.should_receive(:list_resource_record_sets).with(/Z111111111111/).and_return([alias_record])
        @mock_interface.should_receive(:delete_resource_record_sets).with(/Z111111111111/, [alias_record.dup])

        @r53.remove_alias_records('example.net')
      end
    end
  end
end
