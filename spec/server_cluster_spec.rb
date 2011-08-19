require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class SampleServer < Awsborn::Server
  instance_type :m1_small
  image_id 'ami-2fc2e95b'
  keys :all
end

describe Awsborn::ServerCluster do

  before(:each) do
    Awsborn.verbose = false
  end

  describe "build" do
    it "adds the domain to servers" do
      c = Awsborn::ServerCluster.build SampleServer, 'foo' do
        domain 'example.org'
        server :name, :ip => 'www'
      end
      c.first.elastic_ip.should == 'www.example.org'
    end
    it "adds the domain to load balancers" do
      c = Awsborn::ServerCluster.build SampleServer, 'foo' do
        domain 'example.org'
        load_balancer 'elbe', :dns_alias => 'www', :region => 'eu-west-1'
      end
      c.load_balancers.first.dns_alias.should == 'www.example.org'
    end
  end


end
