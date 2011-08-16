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
                       :describe_load_balancer => "description")
    @listener_fixture = [ { :protocol => :tcp, :load_balancer_port => 123, :instance_port => 123} ]
    @cookies_fixture = [ { :ports => [123], :policy => :disabled } ]
    Awsborn::Elb.stub!(:new).and_return(@mocked_elb)
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
          :region => :eu_west_1a,
          :only => [:server1, :server2],
          :except => [:server2],
          :listeners => @listener_fixture,
          :sticky_cookies => @cookies_fixture
        )
      end
      its(:name)           { should == 'some-name' }
      its(:region)         { should == 'eu-west-1' }
      its(:only)           { should == [:server1, :server2] }
      its(:except)         { should == [:server2] }
      its(:listeners)      { should == @listener_fixture }
      its(:sticky_cookies) { should == @cookies_fixture }
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
    end
  end

  describe "dns_name" do
    it "delegates to elb" do
      @mocked_elb.should_receive(:dns_name).with('some-name').and_return('dns-name')
      @balancer = Awsborn::LoadBalancer.new(
        'some-name',
        :region => :eu_west_1
      ).dns_name.should == 'dns-name'
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

  describe "update_with" do
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
      @balancer.update_with(@new_servers)
    end
    it "does not launch the load balancer if running" do
      @mocked_elb.should_receive(:running?).with('some-name').and_return(true)
      @mocked_elb.should_not_receive(:create_load_balancer)
      @balancer.update_with(@new_servers)
    end
    it "sets new instances, sets new zones, updates listeners and updates sticky cookies" do
      @balancer.should_receive(:instances=).with(['i-00000001', 'i-00000002'])
      @balancer.should_receive(:zones=).with(['eu-west-1a', 'eu-west-1b'])
      @balancer.should_receive(:update_listeners)
      @balancer.should_receive(:update_sticky_cookies)
      @balancer.should_receive(:description).and_return('description')
      @balancer.update_with(@new_servers).should == 'description'
    end
    it "takes into account the :only option" do
      @balancer.only = [:server1]

      @balancer.should_receive(:instances=).with(['i-00000001'])
      @balancer.should_receive(:zones=).with(['eu-west-1a'])
      @balancer.should_receive(:update_listeners)
      @balancer.should_receive(:update_sticky_cookies)
      @balancer.should_receive(:description).and_return('description')
      @balancer.update_with(@new_servers).should == 'description'
    end
    it "takes into account the :except option" do
      @balancer.except = [:server1]

      @balancer.should_receive(:instances=).with(['i-00000002'])
      @balancer.should_receive(:zones=).with(['eu-west-1b'])
      @balancer.should_receive(:update_listeners)
      @balancer.should_receive(:update_sticky_cookies)
      @balancer.should_receive(:description).and_return('description')
      @balancer.update_with(@new_servers).should == 'description'
    end
  end

end

