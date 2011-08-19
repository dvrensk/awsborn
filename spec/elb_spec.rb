require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Awsborn::Elb do
  before do
    @mock_interface = mock(:elb_interface)
    RightAws::ElbInterface.stub!(:new).and_return(@mock_interface)
    Awsborn.stub!(:access_key_id).and_return('access_key_id')
    Awsborn.stub!(:secret_access_key).and_return('secret_access_key')
  end
  describe "initialize" do
    it "sets a proper endpoint" do
      [:eu_west_1, 'eu-west-1', :eu_west_1a, "eu_west_1b"].each do |zone|
        elb = Awsborn::Elb.new(:eu_west_1)
        elb.region.should == 'eu-west-1'
        elb.endpoint.should == 'https://eu-west-1.elasticloadbalancing.amazonaws.com'
      end
    end
  end

  describe "connection" do
    before do
      @elb = Awsborn::Elb.new(:eu_west_1b)
    end
    it "setup a connection to a proper endpoint the first time" do
      RightAws::ElbInterface.should_receive(:new).
                             with('access_key_id', 'secret_access_key', :logger => Awsborn.logger).
                             exactly(:once)
      @elb.connection
      @elb.connection
    end
  end

  context "for a valid elb" do
    before do
      @elb = Awsborn::Elb.new(:eu_west_1b)
    end

    describe "describe_load_balancer" do
      it "forwards to ElbInterface" do
        @mock_interface.should_receive(:describe_load_balancers).with('some-name').and_return([:description])
        @elb.describe_load_balancer('some-name').should == :description
      end
    end

    describe "running?" do
      it "returns true if load balancer is running" do
        @mock_interface.should_receive(:describe_load_balancers).with('some-name').and_return([:description])
        @elb.running?('some-name').should be_true
      end
      it "returns true if load balancer is not running" do
        @mock_interface.should_receive(:describe_load_balancers).with('some-name').and_raise(RightAws::AwsError)
        @elb.running?('some-name').should be_false
      end
    end

    describe "dns_name" do
      it "extracts name from description" do
        @mock_interface.should_receive(:describe_load_balancers).with('some-name').and_return([{:dns_name => 'dns-name'}])
        @elb.dns_name('some-name').should == 'dns-name'
      end
    end

    describe "instances" do
      it "extracts instances from description" do
        @mock_interface.should_receive(:describe_load_balancers).with('some-name').and_return([{:instances => 'instances'}])
        @elb.instances('some-name').should == 'instances'
      end
    end

    describe "zones" do
      it "extracts zones from description" do
        @mock_interface.should_receive(:describe_load_balancers).with('some-name').and_return([{:availability_zones => 'zones'}])
        @elb.zones('some-name').should == 'zones'
      end
    end

    describe "canonical_hosted_zone_name_id" do
      it "extracts zone id from description" do
        @mock_interface.should_receive(:describe_load_balancers).with('some-name').and_return([{:canonical_hosted_zone_name_id => 'Z000'}])
        @elb.canonical_hosted_zone_name_id('some-name').should == 'Z000'
      end
    end

    describe "create_load_balancer" do
      it "forwards to ElbInterface with a temporary zone and no listeners" do
        @mock_interface.should_receive(:create_load_balancer).with('some-name', ['eu-west-1a'], [])
        @elb.create_load_balancer('some-name')
      end
    end

    describe "set_load_balancer_listeners" do
      it "sets listeners if none where set before" do
        description = {
          :listeners => []
        }
        new_listeners = [
          { :protocol => :http, :load_balancer_port => 80, :instance_port => 80 },
        ]
        @mock_interface.should_receive(:describe_load_balancers).
                        with('some-name').
                        and_return([description])
        @mock_interface.should_not_receive(:delete_load_balancer_listeners)
        @mock_interface.should_receive(:create_load_balancer_listeners).with('some-name', new_listeners)
        @elb.set_load_balancer_listeners('some-name', new_listeners)
      end
      it "updates listeners if some where set before" do
        description = {
          :listeners => [
            { :protocol => :http, :load_balancer_port => 11, :instance_port => 11 },
            { :protocol => :http, :load_balancer_port => 22, :instance_port => 22 },
            { :protocol => :tcp,  :load_balancer_port => 33, :instance_port => 33 }
          ]
        }
        new_listeners = [
          { :protocol => :http, :load_balancer_port => 80, :instance_port => 80 },
        ]
        @mock_interface.should_receive(:describe_load_balancers).
                        with('some-name').
                        and_return([description])
        @mock_interface.should_receive(:delete_load_balancer_listeners).with('some-name', 11, 22, 33)
        @mock_interface.should_receive(:create_load_balancer_listeners).with('some-name', new_listeners)
        @elb.set_load_balancer_listeners('some-name', new_listeners)
      end
    end

    describe "set_lb_cookie_policy" do
      it "creates and sets sticky policy for each given port when the policy is missing" do
        description = {
          :listeners => [
            { :protocol => :http, :load_balancer_port => 11, :instance_port => 11 },
            { :protocol => :http, :load_balancer_port => 22, :instance_port => 22 },
            { :protocol => :tcp,  :load_balancer_port => 33, :instance_port => 33 }
          ],
          :lb_cookie_stickiness_policies => []
        }
        @mock_interface.should_receive(:describe_load_balancers).
                        with('some-name').
                        and_return([description])
        @mock_interface.should_receive(:create_lb_cookie_stickiness_policy).
                        with('some-name', 'lb-some-name-300', 300)
        @mock_interface.should_receive(:set_load_balancer_policies_of_listener).
                        with('some-name', 11, 'lb-some-name-300')
        @mock_interface.should_receive(:set_load_balancer_policies_of_listener).
                        with('some-name', 22, 'lb-some-name-300')
        @elb.set_lb_cookie_policy('some-name', [11, 22], 300)
      end
      it "does not create but sets sticky policy for each given port when the policy exists" do
        description = {
          :listeners => [
            { :protocol => :http, :load_balancer_port => 11, :instance_port => 11 },
            { :protocol => :http, :load_balancer_port => 22, :instance_port => 22 },
            { :protocol => :tcp,  :load_balancer_port => 33, :instance_port => 33 }
          ],
          :lb_cookie_stickiness_policies => [
            { :policy_name => 'lb-some-name-300', :expiration_period => 42 },
          ]
        }
        @mock_interface.should_receive(:describe_load_balancers).
                        with('some-name').
                        and_return([description])
        @mock_interface.should_not_receive(:create_lb_cookie_stickiness_policy)
        @mock_interface.should_receive(:set_load_balancer_policies_of_listener).
                        with('some-name', 11, 'lb-some-name-300')
        @mock_interface.should_receive(:set_load_balancer_policies_of_listener).
                        with('some-name', 22, 'lb-some-name-300')
        @elb.set_lb_cookie_policy('some-name', [11, 22], 300)
      end
    end

    describe "set_app_cookie_policy" do
      it "creates and sets sticky policy for each given port when the policy is missing" do
        description = {
          :listeners => [
            { :protocol => :http, :load_balancer_port => 11, :instance_port => 11 },
            { :protocol => :http, :load_balancer_port => 22, :instance_port => 22 },
            { :protocol => :tcp,  :load_balancer_port => 33, :instance_port => 33 }
          ],
          :app_cookie_stickiness_policies => []
        }
        @mock_interface.should_receive(:describe_load_balancers).
                        with('some-name').
                        and_return([description])
        @mock_interface.should_receive(:create_app_cookie_stickiness_policy).
                        with('some-name', 'app-some-name--some-cookie', "_some_cookie")
        @mock_interface.should_receive(:set_load_balancer_policies_of_listener).
                        with('some-name', 11, 'app-some-name--some-cookie')
        @mock_interface.should_receive(:set_load_balancer_policies_of_listener).
                        with('some-name', 22, 'app-some-name--some-cookie')
        @elb.set_app_cookie_policy('some-name', [11, 22], "_some_cookie")
      end
      it "does not create but sets sticky policy for each given port when the policy exists" do
        description = {
          :listeners => [
            { :protocol => :http, :load_balancer_port => 11, :instance_port => 11 },
            { :protocol => :http, :load_balancer_port => 22, :instance_port => 22 },
            { :protocol => :tcp,  :load_balancer_port => 33, :instance_port => 33 }
          ],
          :app_cookie_stickiness_policies => [
            { :policy_name => 'app-some-name--some-cookie', :expiration_period => 42 },
          ]
        }
        @mock_interface.should_receive(:describe_load_balancers).
                        with('some-name').
                        and_return([description])
        @mock_interface.should_not_receive(:create_app_cookie_stickiness_policy)
        @mock_interface.should_receive(:set_load_balancer_policies_of_listener).
                        with('some-name', 11, 'app-some-name--some-cookie')
        @mock_interface.should_receive(:set_load_balancer_policies_of_listener).
                        with('some-name', 22, 'app-some-name--some-cookie')
        @elb.set_app_cookie_policy('some-name', [11, 22], "_some_cookie")
      end
    end

    describe "remove_all_cookie_policies" do
      it "removes all policies from listeners" do
        description = {
          :listeners => [
            { :protocol => :http, :load_balancer_port => 11, :instance_port => 11 },
            { :protocol => :http, :load_balancer_port => 22, :instance_port => 22 },
            { :protocol => :tcp,  :load_balancer_port => 33, :instance_port => 33 }
          ],
          :app_cookie_stickiness_policies => []
        }
        @mock_interface.should_receive(:describe_load_balancers).
                        with('some-name').
                        and_return([description])
        @mock_interface.should_receive(:set_load_balancer_policies_of_listener).with('some-name', 11)
        @mock_interface.should_receive(:set_load_balancer_policies_of_listener).with('some-name', 22)
        @mock_interface.should_receive(:set_load_balancer_policies_of_listener).with('some-name', 33)
        @elb.remove_all_cookie_policies('some-name')
      end
    end

    describe "register_instances" do
      it "forwards to ElbInterface" do
        @mock_interface.should_receive(:register_instances_with_load_balancer).with('some-name', 'i-00000001', 'i-00000002')
        @elb.register_instances('some-name', ['i-00000001', 'i-00000002'])
      end
    end

    describe "deregister_instances" do
      it "forwards to ElbInterface" do
        @mock_interface.should_receive(:deregister_instances_with_load_balancer).with('some-name', 'i-00000001', 'i-00000002')
        @elb.deregister_instances('some-name', ['i-00000001', 'i-00000002'])
      end
    end

    describe "enable_zones" do
      it "forwards to ElbInterface" do
        @mock_interface.should_receive(:enable_availability_zones_for_load_balancer).with('some-name', 'eu-west-1a', 'eu-west-1b')
        @elb.enable_zones('some-name', ['eu-west-1a', 'eu-west-1b'])
      end
    end

    describe "disable_zones" do
      it "forwards to ElbInterface" do
        @mock_interface.should_receive(:disable_availability_zones_for_load_balancer).with('some-name', 'eu-west-1a', 'eu-west-1b')
        @elb.disable_zones('some-name', ['eu-west-1a', 'eu-west-1b'])
      end
    end

    describe "configure_health_check" do
      it "forwards to ElbInterface" do
        @mock_interface.should_receive(:configure_health_check).with('some-name', 'health-check-config')
        @elb.configure_health_check('some-name', 'health-check-config')
      end
    end

    describe "health_status" do
      it "returns the health status of each instance of the load balancer" do
        @mock_interface.should_receive(:describe_load_balancers).with('some-name').and_return([{:instances => 'instances'}])
        @mock_interface.should_receive(:describe_instance_health).with('some-name', 'instances').and_return("health_status")
        @elb.health_status('some-name')
      end
    end
  end
end

