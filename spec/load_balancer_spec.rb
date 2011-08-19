require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Awsborn::LoadBalancer do
  before do
    @mocked_elb = mock(:elb,
                       :running? => false,
                       :remove_all_cookie_policies => true,
                       :create_load_balancer => {},
                       :instances => [],
                       :zones => [],
                       :register_instances => true,
                       :enable_zones => true,
                       :set_load_balancer_listeners => true,
                       :describe_load_balancer => "description",
                       :dns_name => 'asdf',
                       :configure_health_check => true)
    Awsborn::Elb.stub!(:new).and_return(@mocked_elb)

    @mocked_route53 = mock(:route53,
      :zone_exists? => true,
      :add_alias_record => true,
      :alias_target => 'some-name-0001.lb.amz.com'
    )

    @listener_fixture = [ { :protocol => :tcp, :load_balancer_port => 123, :instance_port => 123} ]
    @cookies_fixture = [ { :ports => [123], :policy => :disabled } ]
    @health_check_fixture = {
      :healthy_threshold => 9,
      :unhealthy_threshold => 3,
      :target => "TCP:433",
      :timeout => 6,
      :interval => 31
    }
  end

  describe "initialize" do
    it "requires a valid region option" do
      expect { Awsborn::LoadBalancer.new('some-name') }.to raise_error
      expect { Awsborn::LoadBalancer.new('some-name', :region => :blabla) }.to raise_error
    end
    describe "sets all attributes properly" do
      subject do
        @balancer = Awsborn::LoadBalancer.new(
          'some-name',
          :dns_alias => 'www.example.net',
          :region => :eu_west_1,
          :only => [:server1, :server2],
          :except => [:server2],
          :listeners => @listener_fixture,
          :sticky_cookies => @cookies_fixture,
          :health_check => @health_check_fixture
        )
      end
      its(:name)           { should == 'some-name' }
      its(:dns_alias)      { should == 'www.example.net' }
      its(:region)         { should == 'eu-west-1' }
      its(:only)           { should == [:server1, :server2] }
      its(:except)         { should == [:server2] }
      its(:listeners)      { should == @listener_fixture }
      its(:sticky_cookies) { should == @cookies_fixture }
      its(:health_check_config) { should == @health_check_fixture }
    end
    describe "sets proper default values" do
      subject do
        @balancer = Awsborn::LoadBalancer.new(
          'some-name',
          :region => :eu_west_1
        )
      end
      its(:only)           { should == [] }
      its(:except)         { should == [] }
      its(:listeners)      { should == Awsborn::LoadBalancer::DEFAULT_LISTENERS }
      its(:sticky_cookies) { should == [] }
      its(:health_check_config) { should == Awsborn::LoadBalancer::DEFAULT_HEALTH_CONFIG }
    end
    it "accepts partial health config" do
      balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1,
        :health_check => { :target => 'HTTP:80/test.html' }
      )
      balancer.health_check_config[:target].should == 'HTTP:80/test.html'
      [:healthy_threshold, :unhealthy_threshold, :timeout, :interval].each do |other_attribute|
        balancer.health_check_config[other_attribute].should ==
          Awsborn::LoadBalancer::DEFAULT_HEALTH_CONFIG[other_attribute]
      end
    end
  end

  describe "aws_dns_name" do
    it "delegates to elb" do
      @mocked_elb.should_receive(:dns_name).with('some-name').and_return('dns-name')
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1
      ).aws_dns_name.should == 'dns-name'
    end
  end

  describe "instances" do
    it "delegates to elb" do
      @mocked_elb.should_receive(:instances).with('some-name').and_return('instances')
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1
      ).instances.should == 'instances'
    end
  end

  describe "instances=" do
    it "sets instances properly when the load balancer has no previous instances" do
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1
      )
      @balancer.stub!(:instances).and_return([])
      @mocked_elb.should_receive(:register_instances).with('some-name', ['i-00000001', 'i-00000002'])
      @mocked_elb.should_not_receive(:deregister_instances)
      @balancer.instances = ['i-00000001', 'i-00000002']
    end
    it "does nothing if the previous instances are the same as the ones to be set" do
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1
      )
      @balancer.stub!(:instances).and_return(['i-00000001', 'i-00000002'])
      @mocked_elb.should_not_receive(:register_instances)
      @mocked_elb.should_not_receive(:deregister_instances)
      @balancer.instances = ['i-00000001', 'i-00000002']
    end
    it "removes and adds instances accorind to previous and new state" do
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1
      )
      @balancer.stub!(:instances).and_return(['i-00000001', 'i-00000002'])
      @mocked_elb.should_receive(:register_instances).with('some-name', ['i-00000003'])
      @mocked_elb.should_receive(:deregister_instances).with('some-name', ['i-00000001'])
      @balancer.instances = ['i-00000002', 'i-00000003']
    end
  end

  describe "zones" do
    it "delegates to elb" do
      @mocked_elb.should_receive(:zones).with('some-name').and_return('zones')
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1
      ).zones.should == 'zones'
    end
  end

  describe "zones=" do
    it "sets zones properly when the load balancer has no previous zones" do
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1
      )
      @balancer.stub!(:zones).and_return([])
      @mocked_elb.should_receive(:enable_zones).with('some-name', ['eu-west-1a', 'eu-west-1b'])
      @mocked_elb.should_not_receive(:disable_zones)
      @balancer.zones = ['eu-west-1a', 'eu-west-1b']
    end
    it "does nothing if the previous zones are the same as the ones to be set" do
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1
      )
      @balancer.stub!(:zones).and_return(['eu-west-1a', 'eu-west-1b'])
      @mocked_elb.should_not_receive(:enable_zones)
      @mocked_elb.should_not_receive(:disable_zones)
      @balancer.zones = ['eu-west-1a', 'eu-west-1b']
    end
    it "removes and adds zones accordind to previous and new state" do
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1
      )
      @balancer.stub!(:zones).and_return(['eu-west-1a', 'eu-west-1b'])
      @mocked_elb.should_receive(:enable_zones).with('some-name', ['eu-west-1c'])
      @mocked_elb.should_receive(:disable_zones).with('some-name', ['eu-west-1a'])
      @balancer.zones = ['eu-west-1b', 'eu-west-1c']
    end
  end

  describe "description" do
    it "delegates to elb" do
      @mocked_elb.should_receive(:describe_load_balancer).with('some-name').and_return('description')
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1
      ).description.should == 'description'
    end
  end

  describe "launch" do
    it "delegates to elb" do
      @mocked_elb.should_receive(:create_load_balancer).with('some-name')
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1
      ).launch
    end
  end

  describe "health_status" do
    it "delegates to elb" do
      @mocked_elb.should_receive(:health_status).with('some-name').and_return('health_status')
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1
      ).health_status.should == 'health_status'
    end
  end

  describe "update_health_config" do
    it "delegates to elb" do
      @mocked_elb.should_receive(:configure_health_check).with('some-name', @health_check_fixture)
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1,
        :health_check => @health_check_fixture
      ).update_health_config
    end
  end

  describe "update_listeners" do
    it "delegates to elb" do
      @mocked_elb.should_receive('set_load_balancer_listeners').with('some-name', @listener_fixture)
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1,
        :listeners => @listener_fixture
      ).update_listeners
    end
  end

  describe "update_sticky_cookies" do
    it "sets proper policies" do
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1,
        :sticky_cookies => [
          { :ports => [11,22], :policy => :disabled },
          { :ports => [33], :policy => :app_generated, :cookie_name => 'some_cookie' },
          { :ports => [44], :policy => :lb_generated, :expiration_period => 42 }
        ]
      )
      @mocked_elb.should_receive(:remove_all_cookie_policies).with('some-name')
      @mocked_elb.should_receive(:set_app_sticky_cookie).with('some-name', [33], 'some_cookie')
      @mocked_elb.should_receive(:set_lb_sticky_cookie).with('some-name', [44], 42)

      @balancer.update_sticky_cookies
    end

    it "raises an error if a policy is missing a ports option" do
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1,
        :sticky_cookies => [
          { :policy => :disabled },
        ]
      )
      expect { @balancer.update_sticky_cookies }.to raise_error
    end
    it "raises an error if an app sticky policy is missing a cookie name" do
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1,
        :sticky_cookies => [
          { :ports => [33], :policy => :app_generated },
        ]
      )
      expect { @balancer.update_sticky_cookies }.to raise_error
    end
    it "raises an error if an lb sticky policy is missing an expiration period" do
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1,
        :sticky_cookies => [
          { :ports => [44], :policy => :lb_generated }
        ]
      )
      expect { @balancer.update_sticky_cookies }.to raise_error
    end
  end

  describe "launch_or_update" do
    before do
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1a,
        :listeners => @listener_fixture,
        :sticky_cookies => @cookies_fixture
      )
      @new_servers = [
        mock(:server1, :name => :server1, :instance_id => 'i-00000001', :zone => :eu_west_1a),
        mock(:server1, :name => :server2, :instance_id => 'i-00000002', :zone => :eu_west_1b)
      ]
    end
    it "launches the load balancer if not running" do
      @mocked_elb.should_receive(:running?).with('some-name').and_return(false)
      @mocked_elb.should_receive(:create_load_balancer).with('some-name').and_return(nil)
      @balancer.launch_or_update(@new_servers)
    end
    it "does not launch the load balancer if running" do
      @mocked_elb.should_receive(:running?).with('some-name').and_return(true)
      @mocked_elb.should_not_receive(:create_load_balancer)
      @balancer.launch_or_update(@new_servers)
    end
    it "sets instances and new zones and updates listeners, sticky cookies and health config" do
      @balancer.should_receive(:instances=).with(['i-00000001', 'i-00000002'])
      @balancer.should_receive(:zones=).with(['eu-west-1a', 'eu-west-1b'])
      @balancer.should_receive(:update_listeners)
      @balancer.should_receive(:update_sticky_cookies)
      @balancer.should_receive(:update_health_config)
      @balancer.launch_or_update(@new_servers)
    end
    it "takes into account the :only option" do
      @balancer.only = [:server1]

      @balancer.should_receive(:instances=).with(['i-00000001'])
      @balancer.should_receive(:zones=).with(['eu-west-1a'])
      @balancer.should_receive(:update_listeners)
      @balancer.should_receive(:update_sticky_cookies)
      @balancer.should_receive(:update_health_config)
      @balancer.launch_or_update(@new_servers)
    end
    it "takes into account the :except option" do
      @balancer.except = [:server1]

      @balancer.should_receive(:instances=).with(['i-00000002'])
      @balancer.should_receive(:zones=).with(['eu-west-1b'])
      @balancer.should_receive(:update_listeners)
      @balancer.should_receive(:update_sticky_cookies)
      @balancer.should_receive(:update_health_config)
      @balancer.should_receive(:description).and_return('description')
      @balancer.launch_or_update(@new_servers)
      @balancer.description.should == 'description'
    end
    it "configures dns" do
      @balancer.dns_alias = 'www.example.net'
      @balancer.should_receive(:configure_dns)
      @balancer.launch_or_update(@new_servers)
    end
  end

  describe "configure_dns" do
    before do
      @balancer = Awsborn::LoadBalancer.new('some-name', :region => :eu_west_1, :dns_alias => 'www.example.net')
      @balancer.stub!(:route53).and_return(@mocked_route53)
      @balancer.stub!(:aws_dns_name).and_return('some-name-0001.lb.amz.com')
      @balancer.stub!(:canonical_hosted_zone_name_id).and_return('Z0000000000')
    end

    it "creates the zone if it does not exist" do
      @mocked_route53.should_receive(:create_zone).with('www.example.net')
      @mocked_route53.should_receive(:zone_exists?).with('www.example.net').and_return(false)
      @balancer.configure_dns
    end

    it "doesn't create the zone if it already exists" do
      @mocked_route53.should_not_receive(:create_zone)
      @mocked_route53.should_receive(:zone_exists?).with('www.example.net').and_return(true)
      @balancer.configure_dns
    end

    it "adds the load balancer name as an Alias record" do
      @mocked_route53.should_receive(:alias_target).with('www.example.net').and_return(nil)
      @mocked_route53.should_receive(:add_alias_record).with(:alias => 'www.example.net',
        :lb_fqdn => 'some-name-0001.lb.amz.com', :lb_zone => 'Z0000000000')
      @balancer.configure_dns
    end

    it "removes an outdated alias record" do
      @mocked_route53.should_receive(:alias_target).with('www.example.net').and_return('old-name-1.lb.amz.com')
      @mocked_route53.should_receive(:remove_alias_records).with('www.example.net')
      @mocked_route53.should_receive(:add_alias_record).with(:alias => 'www.example.net',
        :lb_fqdn => 'some-name-0001.lb.amz.com', :lb_zone => 'Z0000000000')
      @balancer.configure_dns
    end

    it "doesn't touch the records if they are OK" do
      @mocked_route53.should_not_receive(:add_alias_record)
      @mocked_route53.should_not_receive(:remove_alias_records)
      @balancer.configure_dns
    end
  end
end
